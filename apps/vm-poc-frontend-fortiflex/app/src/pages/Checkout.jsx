import React from "react";
import { useCart } from "../context/CartContext";
import { useNavigate } from "react-router-dom";

export default function Checkout() {
  const { cart, clearCart } = useCart();
  const navigate = useNavigate();

  const handleSubmit = (e) => {
    e.preventDefault();
    clearCart();
    navigate("/status");
  };

  return (
    <form onSubmit={handleSubmit}>
      <h1 className="text-2xl font-bold mb-4">Checkout</h1>
      <input required placeholder="Name" className="border p-2 w-full mb-2" />
      <input required placeholder="Email" className="border p-2 w-full mb-2" />
      <button className="bg-fortinet-red text-white px-4 py-2 rounded" type="submit">Submit Order</button>
    </form>
  );
}