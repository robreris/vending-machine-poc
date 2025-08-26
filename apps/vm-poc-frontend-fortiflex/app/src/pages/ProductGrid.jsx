import React, { useEffect, useState } from "react";
import ProductCard from "../components/ProductCard";
import { fetchProducts } from "../api/products";

export default function ProductGrid() {
  const [products, setProducts] = useState([]);

  useEffect(() => {
    async function loadProducts() {
      try {
        const [productsRes] = await Promise.all([
          fetchProducts(),
        ]);

        setProducts([...productsRes]);
      } catch (err) {
        console.error("Failed to load products", err);
      }
    }

    loadProducts();
  }, []);

  return (
    <>
      <section className="mb-6 space-y-2">
        <p className="text-2xl font-bold text-red-600">Instructions for Using this PoC *********FOR DEMO PURPOSES ONLY*************</p>
        <p className="text-xl font-semibold text-gray-800">The 5 products below are just to test the frontend &lt;--&gt; Backend Connection... they don't do much</p>
        <p className="text-xl font-semibold text-gray-800">To see real data, login with a CloudCSE Workshop account (@fortinetcloud.onmicrosoft.com)</p>
        <p className="text-lg font-medium text-gray-700">Enter REAL DATA from your FortiFlex Account into the API Credentials Page in the Header Bar</p>
        <p className="text-lg font-medium text-gray-700">After that, the FortiFlex Configurations &amp; Entitlements Pages will show REAL DATA from your FortiFlex Account</p>
      </section>
      
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
        {products.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))}
      </div>
    </>
  );
}