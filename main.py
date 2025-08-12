import os
import uvicorn
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, pipeline, logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
from urllib.parse import urlparse
import asyncio

from dotenv import load_dotenv

load_dotenv()

logging.set_verbosity_error()

MODEL_NAME = os.getenv("MODEL_NAME", "defog/sqlcoder-7b-2")
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is required!")


result = urlparse(DATABASE_URL)
DB_USER = result.username
DB_PASSWORD = result.password
DB_NAME = result.path[1:]
DB_HOST = result.hostname
DB_PORT = result.port


app = FastAPI(
    title="SQLCoder API",
    version="1.0",
    docs_url="/"
)

print(f"Loading model {MODEL_NAME} ...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    trust_remote_code=True,
    torch_dtype=torch.float16,
    device_map="auto",
    use_cache=True,
    # load_in_8bit=True,
    load_in_4bit=True,
)

pipe = pipeline(
    "text-generation",
    model=model,
    tokenizer=tokenizer,
    max_new_tokens=128,
    do_sample=False,
    return_full_text=False,
    num_beams=1,
)

def build_prompt(prompt_template: str, question: str, metadata: str) -> str:
    return prompt_template.format(
        user_question=question,
        table_metadata_string=metadata
    )

def generate_sql_from_prompt(full_prompt: str) -> str:
    eos_token_id = tokenizer.eos_token_id
    generated_query = (
        pipe(
            full_prompt,
            num_return_sequences=1,
            eos_token_id=eos_token_id,
            pad_token_id=eos_token_id,
        )[0]["generated_text"]
        .split(";")[0]
        .split("```")[0]
        .strip()
    )
    return generated_query

def run_sql_sync(query: str):
    conn = psycopg2.connect(
        database = DB_NAME,
        user = DB_USER,
        password = DB_PASSWORD,
        host = DB_HOST,
        port = DB_PORT
    )
    cur = conn.cursor()
    cur.execute(query)
    colnames = [desc[0] for desc in cur.description] if cur.description else []
    rows = cur.fetchall() if cur.description else []
    cur.close()
    conn.close()
    return [dict(zip(colnames, row)) for row in rows]

# --- REQUEST MODEL ---
class GenerateRequest(BaseModel):
    question: str
    metadata: str
    prompt: str

@app.post("/generate")
async def generate(req: GenerateRequest):
    try:
        full_prompt = build_prompt(req.prompt, req.question, req.metadata)
        print("Question: " + req.question)

        sql_query = generate_sql_from_prompt(full_prompt).strip()
        
        if sql_query == "":
            print(f"SQL query hasn't generated!")

        print(f"Generated SQL: {sql_query}")

        if not sql_query or "i do not know" in sql_query.lower():
            return {
                "question": req.question,
                "sql": sql_query,
                "results": [],
                "error": "Model could not generate a valid SQL query."
            }

        if not sql_query.endswith(";"):
            sql_query += ";"

        results = await asyncio.to_thread(run_sql_sync, sql_query)

        return {
            "question": req.question,
            "sql": sql_query,
            "results": results
        }

    except psycopg2.Error as db_err:
        return {
            "status_code": 400,
            "detail": f"SQL Error: {db_err.pgerror}",
            "sql": sql_query
        }
    except Exception as e:
        return {
            "status_code": 500,
            "detail": f"Error: {e}",
            "sql": sql_query
        }

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
