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
