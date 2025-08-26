import { Link } from "react-router-dom";
import LoginButton from './LoginButton';
import { useSession } from "../context/SessionContext";

export default function Header() {
  const { user, logout } = useSession();

  return (
    <header className="bg-white shadow p-4 flex justify-between items-center">
      <h1 className="text-2xl font-bold text-red-600">CloudCSE FortiFlex Marketplace</h1>
      <nav className="flex gap-4 items-center">
        <Link to="/" className="text-gray-800 hover:text-red-600">Home</Link>
        <Link to="/submit-api-creds" className="text-gray-800 hover:text-red-600">API Credentials</Link>
        <Link to="/fortiflex-configs" className="hover:text-blue-500">  FortiFlex Configs</Link>
        <Link to="/fortiflex-entitlements" className="hover:text-blue-500">FortiFlex Entitlements</Link>
        <Link to="/sampleproducts" className="hover:text-blue-500">  Dummy Products</Link>
        <Link to="/cart" className="text-gray-800 hover:text-red-600">Cart</Link>
        <Link to="/status" className="text-gray-800 hover:text-red-600">Status</Link>
        {user ? (
          <>
            <span className="text-sm text-gray-600">Welcome, {user.nameid}</span>
            <button
              onClick={() => {
                logout();
                window.location.href = "/";
              }}
              className="bg-red-600 text-white px-3 py-1 rounded hover:bg-red-700 text-sm"
            >
              Logout
            </button>
          </>
        ) : (
          <LoginButton />
        )}
      </nav>
    </header>
  );
}
