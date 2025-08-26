import React from "react";
import { useCart } from "../context/CartContext";

export default function ProductCard({ product }) {
  const { addToCart } = useCart();

  return (
    <div className="border rounded p-4 shadow hover:shadow-lg">
      <img src={product.image_url} alt={product.name} className="w-full h-40 object-cover mb-2" />
      <h2 className="text-lg font-semibold">{product.name}</h2>
      <p className="text-gray-600">{product.description}</p>
      <p className="font-bold text-fortinet-red">${product.price}</p>
      <button onClick={() => addToCart(product)} className="mt-2 bg-fortinet-red text-white px-4 py-2 rounded">
        Add to Cart
      </button>
    </div>
  );
}