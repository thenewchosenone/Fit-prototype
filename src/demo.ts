import { validatePublicDemoEnvironment } from "./demoConfig";

export const publicDemoMode = import.meta.env.VITE_PUBLIC_DEMO === "true";
export const demoAuthRequested = import.meta.env.VITE_AUTH_DEMO_MODE === "true";
export const demoWelcomeStorageKey = "liftrank-public-demo-welcome-v1";

validatePublicDemoEnvironment(import.meta.env);

export function isPublicDemoPath(pathname: string) {
  return ["/demo", "/privacy", "/terms", "/contact"].includes(pathname);
}
