// src/pages/SubmitAPICreds.jsx
import { useState } from "react";
import { VITE_BACKEND_HOST } from "../config";

export default function SubmitAPICreds() {
  const [username, setUsername] = useState("");
  const [apiKey, setApiKey] = useState("");
  const [serialNumber, setSerialNumber] = useState("");
  const [accountId, setAccountId] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitted(false);
    setError(null);

    try {
      const response = await fetch(`${VITE_BACKEND_HOST}/api/fortiflex/credentials`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        credentials: "include",
        body: JSON.stringify({ username, apiKey, serialNumber, accountId }),
      });

      if (!response.ok) throw new Error("Failed to submit credentials");

      setSubmitted(true);
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="max-w-md mx-auto mt-8 p-4 border rounded shadow">
      <h2 className="text-xl font-semibold mb-4">Submit FortiFlex API Credentials</h2>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">API Username</label>
          <input
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="mt-1 block w-full border rounded px-3 py-2"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">API Key</label>
          <input
            type="password"
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
            className="mt-1 block w-full border rounded px-3 py-2"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Program Serial Number</label>
          <input
            type="text"
            value={serialNumber}
            onChange={(e) => setSerialNumber(e.target.value)}
            className="mt-1 block w-full border rounded px-3 py-2"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">FortiCloud Account ID</label>
          <input
            type="text"
            value={accountId}
            onChange={(e) => setAccountId(e.target.value)}
            className="mt-1 block w-full border rounded px-3 py-2"
            required
          />
        </div>
        <button type="submit" className="bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700">
          Submit
        </button>
      </form>
      {submitted && <p className="text-green-600 mt-4">Credentials submitted successfully!</p>}
      {error && <p className="text-red-600 mt-4">Error: {error}</p>}
    </div>
  );
}
