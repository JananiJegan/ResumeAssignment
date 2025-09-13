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
