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
