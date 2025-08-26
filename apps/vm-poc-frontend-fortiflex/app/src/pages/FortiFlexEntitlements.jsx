import React, { useEffect, useState } from "react";
import FortiFlexEntitlementCard from "../components/FortiFlexEntitlementCard";

export default function FortiFlexEntitlementsPage() {
  const [entitlements, setEntitlements] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchEntitlements = async () => {
      try {
        const res = await fetch(`/api/fortiflex/entitlements/list-all`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json"
          },
          credentials: "include"
        });
        if (!res.ok) {
          throw new Error("Failed to fetch FortiFlex entitlements");
        }
        const data = await res.json();
        setEntitlements(data.entitlements || []);
      } catch (err) {
        setError(err.message);
      }
    };

    fetchEntitlements();
  }, []);

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-4">FortiFlex Entitlements</h1>
      {error && <p className="text-red-500">Error: {error}</p>}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {entitlements.map((entitlement) => (
          <FortiFlexEntitlementCard key={entitlement.serialNumber} entitlement={entitlement} />
        ))}
      </div>
    </div>
  );
}
