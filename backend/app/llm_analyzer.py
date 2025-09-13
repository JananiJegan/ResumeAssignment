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
