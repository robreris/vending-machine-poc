// src/context/AppDataContext.jsx
//don't really need this unless we want to do App-Wide data caching/local storage
import React, { createContext, useContext, useState, useEffect } from 'react';

const AppDataContext = createContext();

export const AppDataProvider = ({ children }) => {
  const [productTypes, setProductTypes] = useState([]);

  useEffect(() => {
    const cached = localStorage.getItem('productTypes');
    if (cached) {
      setProductTypes(JSON.parse(cached));
    } else {
      fetch('https://your-backend/api/product-types', { credentials: "include" })
        .then(res => res.json())
        .then(data => {
          setProductTypes(data);
          localStorage.setItem('productTypes', JSON.stringify(data));
        })
        .catch(err => console.error("Error fetching product types", err));
    }
  }, []);

  return (
    <AppDataContext.Provider value={{ productTypes }}>
      {children}
    </AppDataContext.Provider>
  );
};

export const useAppData = () => useContext(AppDataContext);