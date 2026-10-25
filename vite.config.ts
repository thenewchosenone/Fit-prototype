import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import { validatePublicDemoEnvironment } from "./src/demoConfig";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, ".", "");
  validatePublicDemoEnvironment(env);
  return {
    base: "./",
    plugins: [react()]
  };
});
