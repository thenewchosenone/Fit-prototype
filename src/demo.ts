import { validatePublicDemoEnvironment } from "./demoConfig";

export const publicDemoMode = import.meta.env.VITE_PUBLIC_DEMO === "true";
export const demoWelcomeStorageKey = "liftrank-public-demo-welcome-v1";

validatePublicDemoEnvironment(import.meta.env);
