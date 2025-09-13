#!/bin/bash
set -e

# === CONFIG ===
PROJECT_NAME="resume-analyzer"
FRONTEND_PORT=3000
BACKEND_PORT=8000

echo "🚀 Setting up $PROJECT_NAME ..."

# Create project root
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# ============================
# BACKEND (FastAPI + SQLite)
# ============================
mkdir -p backend/app

cat > backend/app/main.py << 'EOF'
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import shutil, os, json
from .resume_parser import parse_resume
from .llm_analyzer import analyze_resume
from .database import init_db, save_resume, get_all_resumes, get_resume_by_id

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

init_db()

UPLOAD_DIR = "uploaded_resumes"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.post("/upload/")
async def upload_resume(file: UploadFile = File(...)):
    try:
        file_path = os.path.join(UPLOAD_DIR, file.filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        extracted = parse_resume(file_path)
        analysis = analyze_resume(extracted)
        resume_id = save_resume(file.filename, extracted, analysis)

        return {"id": resume_id, "file_name": file.filename, "extracted": extracted, "analysis": analysis}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/resumes/")
async def list_resumes():
    return get_all_resumes()

@app.get("/resumes/{resume_id}")
async def resume_details(resume_id: int):
    return get_resume_by_id(resume_id)
EOF

cat > backend/app/resume_parser.py << 'EOF'
from pyresparser import ResumeParser

def parse_resume(file_path: str):
    try:
        data = ResumeParser(file_path).get_extracted_data()
        if not data:
            return {}
        return {
            "name": data.get("name"),
            "email": data.get("email"),
            "phone": data.get("mobile_number"),
            "skills": data.get("skills"),
            "education": data.get("degree"),
            "experience": data.get("experience"),
            "companies": data.get("company_names"),
            "designation": data.get("designation"),
            "total_experience": data.get("total_experience"),
        }
    except Exception as e:
        return {"error": str(e)}
EOF

cat > backend/app/llm_analyzer.py << 'EOF'
import os
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.prompts import PromptTemplate

GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")

def analyze_resume(extracted: dict):
    if not GOOGLE_API_KEY:
        return {"error": "Google API key not set"}

    llm = ChatGoogleGenerativeAI(model="gemini-pro", google_api_key=GOOGLE_API_KEY)

    prompt = PromptTemplate(
        input_variables=["skills", "experience"],
        template=(
            "Given these resume details:\n\nSkills: {skills}\nExperience: {experience}\n\n"
            "1. Rate this resume out of 10.\n"
            "2. Suggest improvement areas.\n"
            "3. Suggest upskilling ideas and courses.\n"
            "4. Highlight strong points."
        ),
    )

    chain = prompt | llm
    response = chain.invoke({"skills": extracted.get("skills"), "experience": extracted.get("experience")})
    return {"analysis_text": response.content}
EOF

cat > backend/app/database.py << 'EOF'
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
EOF

cat > backend/requirements.txt << 'EOF'
fastapi
uvicorn
pyresparser
spacy
langchain
langchain-google-genai
EOF

cat > backend/Dockerfile << 'EOF'
FROM python:3.10

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install spaCy model
RUN python -m spacy download en_core_web_sm

COPY ./app ./app

ENV GOOGLE_API_KEY=""
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# ============================
# FRONTEND (React + Tailwind)
# ============================
mkdir -p frontend/src/components

cat > frontend/package.json << 'EOF'
{
  "name": "resume-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "axios": "^1.6.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "tailwindcss": "^3.4.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  }
}
EOF

cat > frontend/Dockerfile << 'EOF'
FROM node:18

WORKDIR /app
COPY package.json .
RUN npm install
COPY ./src ./src
CMD ["npm", "start"]
EOF

cat > frontend/src/App.js << 'EOF'
import React, { useState, useEffect } from "react";
import UploadResume from "./components/UploadResume";
import ResumeTable from "./components/ResumeTable";
import axios from "axios";

function App() {
  const [tab, setTab] = useState("upload");
  const [resumes, setResumes] = useState([]);

  useEffect(() => {
    if (tab === "history") {
      axios.get("http://localhost:8000/resumes/").then((res) => setResumes(res.data));
    }
  }, [tab]);

  return (
    <div className="p-4">
      <div className="flex space-x-4">
        <button className="bg-blue-500 text-white px-4 py-2 rounded" onClick={() => setTab("upload")}>Upload Resume</button>
        <button className="bg-green-500 text-white px-4 py-2 rounded" onClick={() => setTab("history")}>History</button>
      </div>
      <div className="mt-4">
        {tab === "upload" && <UploadResume />}
        {tab === "history" && <ResumeTable resumes={resumes} />}
      </div>
    </div>
  );
}

export default App;
EOF

cat > frontend/src/components/UploadResume.js << 'EOF'
import React, { useState } from "react";
import axios from "axios";

function UploadResume() {
  const [file, setFile] = useState(null);
  const [result, setResult] = useState(null);

  const handleUpload = async () => {
    const formData = new FormData();
    formData.append("file", file);
    const res = await axios.post("http://localhost:8000/upload/", formData, {
      headers: { "Content-Type": "multipart/form-data" },
    });
    setResult(res.data);
  };

  return (
    <div>
      <input type="file" onChange={(e) => setFile(e.target.files[0])} />
      <button className="bg-blue-600 text-white px-4 py-2 rounded ml-2" onClick={handleUpload}>Upload</button>
      {result && <pre className="mt-4 bg-gray-100 p-4">{JSON.stringify(result, null, 2)}</pre>}
    </div>
  );
}

export default UploadResume;
EOF

cat > frontend/src/components/ResumeTable.js << 'EOF'
import React, { useState } from "react";
import axios from "axios";

function ResumeTable({ resumes }) {
  const [details, setDetails] = useState(null);

  const viewDetails = async (id) => {
    const res = await axios.get(\`http://localhost:8000/resumes/\${id}\`);
    setDetails(res.data);
  };

  return (
    <div>
      <table className="table-auto border w-full">
        <thead>
          <tr>
            <th className="border px-4 py-2">ID</th>
            <th className="border px-4 py-2">File Name</th>
            <th className="border px-4 py-2">Action</th>
          </tr>
        </thead>
        <tbody>
          {resumes.map((r) => (
            <tr key={r.id}>
              <td className="border px-4 py-2">{r.id}</td>
              <td className="border px-4 py-2">{r.file_name}</td>
              <td className="border px-4 py-2">
                <button className="bg-blue-500 text-white px-2 py-1 rounded" onClick={() => viewDetails(r.id)}>Details</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {details && <pre className="mt-4 bg-gray-100 p-4">{JSON.stringify(details, null, 2)}</pre>}
    </div>
  );
}

export default ResumeTable;
EOF

# ============================
# SAMPLE DATA
# ============================
mkdir -p sample_data
echo "Sample resumes go here (PDFs)." > sample_data/README.txt

# ============================
# DOCKER COMPOSE
# ============================
cat > docker-compose.yml << 'EOF'
version: "3.8"
services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
    environment:
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    volumes:
      - ./frontend:/app
    stdin_open: true
    tty: true
EOF

# ============================
# README
# ============================
cat > README.md << 'EOF'
# Resume Analyzer

## Setup
1. Add your Google Gemini API key:
   ```bash
   export GOOGLE_API_KEY="A***"
EOF
