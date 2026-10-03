export type DemoEnvironment = Partial<Record<"VITE_PUBLIC_DEMO" | "VITE_AUTH_DEMO_MODE" | "VITE_SUPABASE_URL" | "VITE_SUPABASE_ANON_KEY", string>>;

export function validatePublicDemoEnvironment(env: DemoEnvironment) {
  if (env.VITE_PUBLIC_DEMO !== "true") return;
  if (env.VITE_SUPABASE_URL?.trim() || env.VITE_SUPABASE_ANON_KEY?.trim()) {
    throw new Error("Public demo builds must not include Supabase credentials.");
  }
  if (env.VITE_AUTH_DEMO_MODE !== "true") {
    throw new Error("Public demo builds require VITE_AUTH_DEMO_MODE=true.");
  }
}
