import React, { useEffect, useState } from "react";
import FortiFlexConfigCard from "../components/FortiFlexConfigCard";

export default function FortiFlexConfigsPage() {
  const [configs, setConfigs] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchConfigs = async () => {
      try {

        const res = await fetch(`/api/fortiflex/configs/list`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json"
          },
          credentials: "include",
        });
        if (!res.ok) {
          throw new Error("Failed to fetch FortiFlex configurations");
        }
        const data = await res.json();
        setConfigs(data.configs || []);
      } catch (err) {
        setError(err.message);
      }
    };

    fetchConfigs();
  }, []);

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-4">FortiFlex Configurations</h1>
      {error && <p className="text-red-500">Error: {error}</p>}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {configs.map((config) => (
          <FortiFlexConfigCard key={config.configId} config={config} />
        ))}
      </div>
    </div>
  );
}
