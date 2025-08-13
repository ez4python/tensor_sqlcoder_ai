import os
import json
import psycopg2
from dotenv import load_dotenv
from urllib.parse import urlparse


load_dotenv()

MODEL_NAME = os.getenv("MODEL_NAME", "defog/sqlcoder-7b-2")
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is required!")


db = urlparse(DATABASE_URL)
DB_USER = db.username
DB_PASSWORD = db.password
DB_NAME = db.path[1:]
DB_HOST = db.hostname
DB_PORT = db.port


def log_sql_error(question: str, error_msg: str, sql_query: str, results):
    """
    Savol xatoni databasega yozish
    1. I dont know
    2. Tushunarsiz db schema
    3. Natija xato
    """
    try:
        conn = psycopg2.connect(
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT
        )
        cur = conn.cursor()

        cur.execute("""
            CREATE TABLE IF NOT EXISTS failed_queries (
                id SERIAL PRIMARY KEY,
                question TEXT,
                sql_query TEXT,
                error TEXT,
                results JSONB,
                feedback BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """)
        
        cur.execute(
            "INSERT INTO failed_queries (question, error, sql_query, results) VALUES (%s, %s, %s, %s)",
            (question, error_msg, json.dumps(results) if results is not None else None)
        )

        conn.commit()
        cur.close()
        conn.close()
    
    except Exception as log_err:
        print(f"Logging failed: {log_err}")
