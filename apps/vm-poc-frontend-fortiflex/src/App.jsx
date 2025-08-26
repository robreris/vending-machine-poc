import { BrowserRouter, Routes, Route } from "react-router-dom";
import { CartProvider } from "./context/CartContext";
import ProductGrid from "./pages/ProductGrid";
import Cart from "./pages/Cart";
import Checkout from "./pages/Checkout";
import Status from "./pages/Status";
import Header from "./components/Header";
import SampleProducts from "./pages/SampleProducts";
import SubmitAPICreds from "./pages/SubmitAPICreds";
import FortiFlexConfigs from "./pages/FortiFlexConfigs";
import FortiFlexEntitlements from "./pages/FortiFlexEntitlements";
import { toast, ToastContainer } from "react-toastify";

function App() {
  return (

    <CartProvider>
      <BrowserRouter>
        <Header />
          <Routes>
            <Route path="/" element={<ProductGrid />} />
            <Route path="/submit-api-creds" element={<SubmitAPICreds />} />
            <Route path="/fortiflex-configs" element={<FortiFlexConfigs />} />
            <Route path="/fortiflex-entitlements" element={<FortiFlexEntitlements />} />
            <Route path="/sampleproducts" element={<SampleProducts />} />
            <Route path="/cart" element={<Cart />} />
            <Route path="/checkout" element={<Checkout />} />
            <Route path="/status" element={<Status />} />
          </Routes>
          <ToastContainer />
      </BrowserRouter>
    </CartProvider>
  );
}

export default App;