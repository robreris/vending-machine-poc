import React from "react";
import { useCart } from "../context/CartContext";
import { Link } from "react-router-dom";

export default function Cart() {
  const { cart } = useCart();
  const total = cart.reduce((sum, item) => sum + item.price, 0);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">Your Cart</h1>
      {cart.length === 0 ? <p>No items in cart.</p> : (
        <div>
          {cart.map((item, i) => (
            <div key={i} className="border-b py-2">{item.name} - ${item.price}</div>
          ))}
          <div className="mt-4 font-bold">Total: ${total}</div>
          <Link to="/checkout" className="mt-4 inline-block bg-fortinet-red text-white px-4 py-2 rounded">Checkout</Link>
        </div>
      )}
    </div>
  );
}