import React from 'react';
import { VITE_BACKEND_HOST } from "../config";

export default function LoginButton() {
  const handleLogin = () => {
    window.location.href = `${VITE_BACKEND_HOST}/login`; // FastAPI SAML endpoint
  };

  return (
    <button
      onClick={handleLogin}
      className="bg-fortinet-red text-white px-4 py-2 rounded"
    >
      Sign In
    </button>
  );
}