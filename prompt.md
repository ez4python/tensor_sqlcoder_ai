### Task
Generate a SQL query to answer [QUESTION]{user_question}[/QUESTION]

### Instructions
- If you cannot answer the question with the available database schema, return 'I do not know'
- If the question does not explicitly specify the number of results or limit, default to returning only 10 results by adding "LIMIT 10" to the SQL query.

### Database Schema
The query will run on a database with the following schema:
{table_metadata_string}

### Answer
Given the database schema, here is the SQL query that answers [QUESTION]{user_question}[/QUESTION]
[SQL]
