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
