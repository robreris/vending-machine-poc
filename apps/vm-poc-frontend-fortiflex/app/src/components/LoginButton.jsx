import React from 'react';

export default function LoginButton() {
  const handleLogin = () => {
    window.location.href = `/login`; // FastAPI SAML endpoint
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
