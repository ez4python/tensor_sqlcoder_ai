import requests
import json
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

question_file = os.path.join(BASE_DIR, 'question.txt')
# schema_file = os.path.join(BASE_DIR, 'metadata.sql')
schema_file = "/home/tensor/coding/vscode/mistral_sql/kimyo_db.md"
prompt_file = os.path.join(BASE_DIR, 'prompt.md')

with open(question_file, 'r', encoding='utf-8') as f:
    question = f.read().strip()

with open(schema_file, 'r', encoding='utf-8') as f:
    db_schema = f.read().strip()

with open(prompt_file, 'r', encoding='utf-8') as f:
    prompt_template = f.read().strip()

HOST = "localhost"
# HOST = "192.168.7.179"

generate_url = f"http://{HOST}:8000/generate"
feedback_url = f"http://{HOST}:8000/feedback"
headers = {'Content-Type': 'application/json'}

payload = {
    "question": question,
    "metadata": db_schema,
    "prompt": prompt_template.format(question=question, metadata=db_schema)
}

response = requests.post(generate_url, headers=headers, data=json.dumps(payload))

if response.status_code == 200:
    data = response.json()
    print("\n📌 SQL so‘rovi:")
    print(data.get("sql", "Yo'q"))

    print("\n📊 Natija:")
    if data.get("results"):
        for row in data["results"]:
            print(row)
    else:
        print("Natija topilmadi yoki xato.")

    if "error_id" in data:
        feedback_input = input("\n❓ Natija to‘g‘rimi? (y/n, default=y): ").strip().lower()
        feedback = True if feedback_input in ("", "y") else False

        fb_payload = {
            "id": data["error_id"],
            "feedback": feedback
        }
        fb_resp = requests.post(feedback_url, headers=headers, data=json.dumps(fb_payload))
        print("📩 Feedback jo‘natildi:", fb_resp.status_code, fb_resp.text)

else:
    print("Xatolik:", response.status_code, response.text)
