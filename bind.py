import re
import json
import requests
import psycopg2


def load_file(file_path):
    """Faylni UTF-8 kodlash bilan o‘qib, matnini qaytaradi."""
    with open(file_path, "r", encoding="utf-8") as f:
        return f.read().strip()

def run_sql_sync(query: str):
    conn = psycopg2.connect(
        database = "kimyo_cleaned_db",
        user = "postgres",
        password = 1,
        host = "192.168.7.179",
        port = "5432"
    )
    cur = conn.cursor()
    cur.execute(query)
    colnames = [desc[0] for desc in cur.description] if cur.description else []
    rows = cur.fetchall() if cur.description else []
    cur.close()
    conn.close()
    return [dict(zip(colnames, row)) for row in rows]


def extract_sql(text: str):
    match = re.search(r"```sql\s+(.*?)```", text, re.S | re.I)
    if match:
        return match.group(1).strip()
    return None


def generate_sql_query():
    # Uch faylni o‘qish
    user_question = load_file('D:/AI_Portfolio/ollama_dev_project/main_eng/question.txt')
    table_schema = load_file('D:/AI_Portfolio/ollama_dev_project/main_eng/schema.txt')
    base_prompt = load_file('D:/AI_Portfolio/ollama_dev_project/main_uz/prompt.md')

    # Barchasini bitta promptga birlashtirish
    full_prompt = (
        f"{base_prompt}\n\n"
        f"### Table Schema:\n{table_schema}\n\n"
        f"### User Question:\n{user_question}\n\n"
        f"SQL:"
    )

    # API so‘rovi
    url = "http://192.168.7.179:11434/api/generate"
    payload = json.dumps({
        "model": "llama3",
        "prompt": full_prompt,
        "stream": False
    })
    headers = {
        'Content-Type': 'application/json'
    }

    response = requests.post(url, headers=headers, data=payload)

    if response.status_code == 200:
        raw_text = response.json().get("response", "").strip()
        print("RAW:", raw_text)
        sql_query = extract_sql(raw_text)
        print("SQL Query:", sql_query)
        if sql_query:
            print("✅ Extracted SQL:\n", sql_query)
            results = run_sql_sync(sql_query)
            return results
        else:
            return "❌ SQL query topilmadi."
    else:
        return f"Error: {response.status_code}\n{response.text}"


if __name__ == "__main__":
    print("\nGenerated SQL query:\n", generate_sql_query())
