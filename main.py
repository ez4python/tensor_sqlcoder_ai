import uvicorn
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, pipeline, logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
import asyncio


from utils import (
    DATABASE_URL,
    MODEL_NAME,
    DB_NAME,
    DB_USER,
    DB_PASSWORD,
    DB_HOST,
    DB_PORT,
    log_sql_error
)


logging.set_verbosity_error()


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
    bnb_4bit_compute_dtype=torch.float16,
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

        response = {
            "question": req.question
        }

        if not sql_query or "i do not know" in sql_query.lower():
            response.update({
                "sql": sql_query,
                "results": None,
                "error": "Model could not generate a valid SQL query (empty or 'I do not know')."
            })
            log_sql_error(
                response["question"],
                response["error"],
                response["sql"],
                response["results"]
                )
            return response

        if not sql_query.endswith(";"):
            sql_query += ";"
            response.update({
                "sql": sql_query
            })

        results = await asyncio.to_thread(run_sql_sync, sql_query)
        
        response.update({
            "results": results,
            "status_code": 200
            })

        return response

    except psycopg2.Error as db_err:
        response.update({
            "status_code": 400,
            "error": f"SQL Error: {db_err}"
        })
        log_sql_error(
            response.get("question"),
            response.get("error"),
            response.get("sql"),
            response.get("results")
        )
        return response
    
    except Exception as e:
        response.update({
            "status_code": 500,
            "error": f"Error: {e}"
        })
        log_sql_error(
            response.get("question"),
            response.get("error"),
            response.get("sql"),
            response.get("results")
        )
        return response

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
