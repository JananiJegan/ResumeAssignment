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
