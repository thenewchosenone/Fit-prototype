import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { HashRouter } from "react-router-dom";
import App from "./App";
import { AuthProvider } from "./auth";
import { TrackerProvider } from "./store";
import "./styles.css";

if (/^#\/gyms(?:\/|$)/.test(window.location.hash)) {
  void import("./gymCatalog").then(({ loadGymCatalog }) => loadGymCatalog()).catch(() => {});
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <HashRouter>
      <AuthProvider><TrackerProvider><App /></TrackerProvider></AuthProvider>
    </HashRouter>
  </StrictMode>
);
