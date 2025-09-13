import sqlite3, json, os

DB_FILE = "resumes.db"

def init_db():
    conn = sqlite3.connect(DB_FILE)
    cur = conn.cursor()
    cur.execute("""CREATE TABLE IF NOT EXISTS resumes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT,
        extracted TEXT,
        analysis TEXT
    )""")
    conn.commit()
    conn.close()

def save_resume(file_name, extracted, analysis):
    conn = sqlite3.connect(DB_FILE)
    cur = conn.cursor()
    cur.execute("INSERT INTO resumes (file_name, extracted, analysis) VALUES (?, ?, ?)",
                (file_name, json.dumps(extracted), json.dumps(analysis)))
    conn.commit()
    resume_id = cur.lastrowid
    conn.close()
    return resume_id

def get_all_resumes():
    conn = sqlite3.connect(DB_FILE)
    cur = conn.cursor()
    cur.execute("SELECT id, file_name FROM resumes")
    rows = cur.fetchall()
    conn.close()
    return [{"id": r[0], "file_name": r[1]} for r in rows]

def get_resume_by_id(resume_id: int):
    conn = sqlite3.connect(DB_FILE)
    cur = conn.cursor()
    cur.execute("SELECT id, file_name, extracted, analysis FROM resumes WHERE id=?", (resume_id,))
    row = cur.fetchone()
    conn.close()
    if row:
        return {"id": row[0], "file_name": row[1], "extracted": json.loads(row[2]), "analysis": json.loads(row[3])}
    return {}
