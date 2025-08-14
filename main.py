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
print("*" * 15)
print("KERAKLI:", model.config.max_position_embeddings)
print("*" * 15)

pipe = pipeline(
    "text-generation",
    model=model,
    tokenizer=tokenizer,
    max_new_tokens=128,
    do_sample=False,
    return_full_text=False,
    num_beams=2,
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

class FeedbackRequest(BaseModel):
    id: int
    feedback: bool

@app.post("/feedback")
async def give_feedback(req: FeedbackRequest):
    try:
        conn = psycopg2.connect(
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT
        )
        cur = conn.cursor()
        cur.execute(
            "UPDATE failed_queries SET feedback = %s WHERE id = %s",
            (req.feedback, req.id)
        )
        conn.commit()
        cur.close()
        conn.close()
        return {
            "status": "ok",
            "id": req.id,
            "feedback": req.feedback
            }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e)
            }

class GenerateRequest(BaseModel):
    question: str
    metadata: str
    prompt: str

@app.post("/generate")
async def generate(req: GenerateRequest):
    response = {
        "question": req.question,
        "sql": None,
        "results": None,
        "status_code": None,
        "error": None
    }
    try:
        # 1️⃣ Promptdan SQL generatsiya
        full_prompt = build_prompt(req.prompt, req.question, req.metadata)
        print("Question:", req.question)
        sql_query = generate_sql_from_prompt(full_prompt).strip()
        response["sql"] = sql_query

        if not sql_query or "i do not know" in sql_query.lower():
            response.update({
                "status_code": 400,
                "error": "Model could not generate a valid SQL query (empty or 'I do not know')."
            })
            error_id = log_sql_error(
                req.question, response["error"], sql_query, None
            )
            response["error_id"] = error_id
            return response

        if not sql_query.endswith(";"):
            sql_query += ";"
            response["sql"] = sql_query

        # 2️⃣ SQL bajarish
        try:
            results = await asyncio.to_thread(run_sql_sync, sql_query)
            response["results"] = results
        except psycopg2.errors.UndefinedColumn as e:
            # Ustun nomi xatosi
            err_msg = f"Undefined column: {str(e).strip()}"
            response.update({
                "status_code": 400,
                "error": err_msg
            })
            error_id = log_sql_error(req.question, err_msg, sql_query, None)
            response["error_id"] = error_id
            return response
        except Exception as e:
            # Har qanday boshqa SQL xatosi
            err_msg = str(e).strip()
            response.update({
                "status_code": 400,
                "error": err_msg
            })
            error_id = log_sql_error(req.question, err_msg, sql_query, None)
            response["error_id"] = error_id
            return response

        # 3️⃣ Bo‘sh natija
        if not response["results"]:
            response.update({
                "status_code": 404,
                "error": "No results found"
            })
            error_id = log_sql_error(req.question, "Empty results", sql_query, [])
            response["error_id"] = error_id

        else:
            response["status_code"] = 200

        return response

    except Exception as e:
        err_msg = str(e).strip()
        response.update({
            "status_code": 500,
            "error": err_msg
        })
        error_id = log_sql_error(req.question, err_msg, response["sql"], response["results"])
        response["error_id"] = error_id
        return response


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
