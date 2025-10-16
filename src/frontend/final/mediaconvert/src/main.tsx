import React from "react";
import ReactDOM from "react-dom/client";
import "./index.css";
import { BrowserRouter, Route, Routes } from "react-router";
import Navbar from "./components/navbar.tsx";
import Footer from "./components/footer.tsx";
import Login from "./pages/login/page.tsx";
import Signup from "./pages/signup/page.tsx";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import UploadMedia from "./pages/upload-media/page.tsx";
import Dashboard from "./pages/dashboard/page.tsx";

const client = new QueryClient({});

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={client}>
    <BrowserRouter>
      <Navbar />
      <Routes>
        <Route path="/" element={<Login />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/signup" element={<Signup />} />
        <Route path="/login" element={<Login />} />
        <Route path="/upload-media" element={<UploadMedia />} />
      </Routes>
      <Footer />
    </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
);
