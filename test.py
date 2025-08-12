import requests
import json
import os


BASE_DIR = os.path.dirname(os.path.abspath(__file__))

question_file = os.path.join(BASE_DIR, 'question.txt')
schema_file = os.path.join(BASE_DIR, 'metadata.sql')
prompt_file = os.path.join(BASE_DIR, 'prompt.md')

with open(question_file, 'r', encoding='utf-8') as f:
    question = f.read().strip()

with open(schema_file, 'r', encoding='utf-8') as f:
    db_schema = f.read().strip()

with open(prompt_file, 'r', encoding='utf-8') as f:
    prompt_template = f.read().strip()

url = "http://192.168.7.179:8000/generate"
headers = {
    'Content-Type': 'application/json'
}

payload = {
    "question": question,
    "metadata": db_schema,
    "prompt": prompt_template
}

response = requests.post(url, headers=headers, data=json.dumps(payload))
data = response.json()
if response.status_code == 200:
    print("Data:", data)
    print("\n📌 SQL so‘rovi:")
    print(data["sql"])
    print("\n📊 Natija:")
    if data.get("results"):
        for row in data["results"]:
            print(row)
else:
    print(
        "Xatolik:",
        response.status_code,
        response.text,
        f"\nSQL-Query: {data["sql"]}"
    )
