import ProductCard from "../components/ProductCard";

const mockProducts = [
  { id: 1, name: "FortiGate VM01", description: "Entry-level NGFW for small deployments", price: "49.99", image: "images/FGT-VM02.png" },
  { id: 2, name: "FortiGate VM02", description: "Mid-tier NGFW with advanced threat protection", price: "99.99", image: "images/FGT-VM02" },
  { id: 3, name: "FortiGate VM04", description: "High-capacity VM for enterprise workloads", price: "199.99", image: "images/FGT-VM02" },
];

export default function SampleProducts() {
  const handleAddToCart = (product) => {
    console.log("Add to cart:", product);
  };

  return (
    <main className="p-6 grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
      {mockProducts.map((product) => (
        <ProductCard key={product.id} product={product} onAdd={handleAddToCart} />
      ))}
    </main>
  );
}
