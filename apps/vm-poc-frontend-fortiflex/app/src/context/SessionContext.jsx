import { createContext, useContext, useEffect, useState } from "react";

export const SessionContext = createContext(null);

export const SessionProvider = ({ children }) => {
  const [session, setSession] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const res = await fetch(`/api/whoami`, {
          credentials: 'include',
        });
        const data = await res.json();
        console.log("User from /api/whoami:", data);
        setSession(data || {});
      } catch (err) {
        console.error("Failed to fetch user:", err);
        setSession({});
      } finally {
        setLoading(false);
      }
    };

    fetchUser();
  }, []);

  const logout = async () => {
    try {
      await fetch(`/logout`, {
        method: "GET",
        credentials: "include",
      });
      setSession({});
      window.location.href = "/";
    } catch (err) {
      console.error("Logout failed:", err);
    }
  };

  return (
    <SessionContext.Provider value={{ ...session, setSession, logout, loading }}>
      {children}
    </SessionContext.Provider>
  );
};

export const useSession = () => useContext(SessionContext);
