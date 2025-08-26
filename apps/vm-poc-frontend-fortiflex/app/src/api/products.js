import { VITE_BACKEND_HOST } from "../config";

export async function fetchProducts() {
  console.log("Fetching products from API...");
  // TO DO Adjust the URL to match your backend API endpoint
  const response = await fetch(`${VITE_BACKEND_HOST}/api/products`);
  console.log("Fetched static products:", response);
  if (!response.ok) throw new Error("Failed to fetch products");
  return response.json();
}