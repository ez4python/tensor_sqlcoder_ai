import os
import re
import asyncio
from urllib.parse import urlparse
from typing import List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv

# Transformers / bitsandbytes
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    BitsAndBytesConfig,
    GenerationConfig,
)
import torch
import psycopg2

# load env
load_dotenv()

MODEL_NAME = os.getenv("MODEL_NAME", "defog/sqlcoder-7b-2")  # yoki mav23/sqlcoder-70b-alpha-GGUF uchun mos o'zgartirish
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is required!")

# parse DB url
result = urlparse(DATABASE_URL)
DB_USER = result.username
DB_PASSWORD = result.password
DB_NAME = result.path[1:] if result.path else ""
DB_HOST = result.hostname
DB_PORT = result.port or 5432

app = FastAPI(title="SQLCoder API", version="1.0", docs_url="/")

# --- Model yuklash: bitsandbytes 4-bit konfiguratsiyasi ---
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4",        # nf4 tavsiya qilinadi LLMlar uchun
    bnb_4bit_compute_dtype=torch.float16
)

print(f"Loading model {MODEL_NAME} ... (this may take a while)")
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, use_fast=True)

model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    trust_remote_code=True,
    quantization_config=bnb_config,
    device_map="auto",         # agar kerak bo'lsa, max_memory paramlarini qo'shing
    torch_dtype=torch.float16,
    low_cpu_mem_usage=True,
)

# generation config (sizga moslashtirish mumkin)
gen_config = GenerationConfig(
    max_new_tokens=256,
    do_sample=False,
    temperature=0.0,
    top_p=0.95,
    num_beams=1,
)

# -- Helper functions --

# Simple blacklist to avoid destructive SQL (extra safety)
DANGEROUS_KEYWORDS = [
    r"\bINSERT\b", r"\bUPDATE\b", r"\bDELETE\b", r"\bDROP\b", r"\bALTER\b",
    r"\bTRUNCATE\b", r"\bCREATE\b", r"\bGRANT\b", r"\bREVOKE\b"
]

def is_safe_sql(query: str) -> bool:
    # only allow SELECT or WITH queries (basic)
    q = query.strip().strip(";").lstrip().upper()
    if not (q.startswith("SELECT") or q.startswith("WITH")):
        return False
    for pat in DANGEROUS_KEYWORDS:
        if re.search(pat, query, flags=re.IGNORECASE):
            return False
    return True

def extract_sql_from_model_output(text: str) -> str:
    """
    Extract SQL code from model output. Look for fences, or 'SQL:' markers.
    Fallback: take first line / sentence ending with semicolon.
    """
    # try triple backticks first
    m = re.search(r"```(?:sql)?\s*(.*?)```", text, flags=re.S | re.I)
    if m:
        return m.group(1).strip()
    # try marker "SQL:" or "Query:"
    m = re.search(r"(?:SQL|Query)\s*[:\-]\s*(.*)", text, flags=re.I | re.S)
    if m:
        candidate = m.group(1).strip()
        # if long, try to cut at first blank line
        candidate = candidate.split("\n\n")[0]
        return candidate.strip()
    # fallback: take up to first semicolon
    if ";" in text:
        return text.split(";")[0] + ";"
    return text.strip()

async def run_sql_sync(query: str):
    # run in thread to avoid blocking loop
    def _run(q):
        conn = psycopg2.connect(
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT
        )
        try:
            with conn.cursor() as cur:
                cur.execute(q)
                if cur.description:
                    colnames = [desc[0] for desc in cur.description]
                    rows = cur.fetchall()
                    return [dict(zip(colnames, row)) for row in rows]
                else:
                    return []
        finally:
            conn.close()
    return await asyncio.to_thread(_run, query)

def build_prompt(prompt_template: str, question: str, metadata: str) -> str:
    return prompt_template.format(user_question=question, table_metadata_string=metadata)

def generate_sql_from_prompt(full_prompt: str) -> str:
    # tokenize + generate via model.generate for deterministic control
    input_ids = tokenizer(full_prompt, return_tensors="pt").input_ids.to(model.device)
    with torch.no_grad():
        outputs = model.generate(
            input_ids,
            generation_config=gen_config,
            max_new_tokens=256,
            eos_token_id=tokenizer.eos_token_id,
            pad_token_id=tokenizer.eos_token_id,
            do_sample=False
        )
    decoded = tokenizer.decode(outputs[0], skip_special_tokens=True)
    # remove the prompt prefix from decoded if present
    if decoded.startswith(full_prompt):
        decoded = decoded[len(full_prompt):]
    sql_candidate = extract_sql_from_model_output(decoded)
    return sql_candidate.strip()

# --- Request model ---
class GenerateRequest(BaseModel):
    question: str
    metadata: str = ""   # table schema, columns, types
    prompt: str          # prompt template where placeholders {user_question} and {table_metadata_string} exist

# --- Endpoint ---
@app.post("/generate")
async def generate(req: GenerateRequest):
    try:
        full_prompt = build_prompt(req.prompt, req.question, req.metadata)
        print("Question:", req.question)

        sql_query = generate_sql_from_prompt(full_prompt).strip()
        print("Raw generated SQL:", sql_query)

        if not sql_query:
            return {"question": req.question, "sql": "", "results": [], "error": "Empty SQL generated."}

        # sanitize: ensure ends with semicolon and is safe
        if not sql_query.endswith(";"):
            sql_query = sql_query + ";"

        if not is_safe_sql(sql_query):
            return {"question": req.question, "sql": sql_query, "results": [], "error": "Generated SQL is unsafe or not a SELECT/WITH query."}

        results = await run_sql_sync(sql_query)

        return {"question": req.question, "sql": sql_query, "results": results}

    except psycopg2.Error as db_err:
        raise HTTPException(status_code=200, detail=f"SQL Error: {db_err.pgerror}")
    except Exception as e:
        raise HTTPException(status_code=200, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
