import { createClient, type Session, type SupabaseClient, type User } from "@supabase/supabase-js";
import { createContext, type PropsWithChildren, useContext, useEffect, useMemo, useState } from "react";
import { publicDemoMode } from "./demo";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim();
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim();
export const authDemoMode = publicDemoMode || import.meta.env.VITE_AUTH_DEMO_MODE === "true" || (!supabaseUrl && import.meta.env.DEV);
export const supabase: SupabaseClient | null = supabaseUrl && supabaseAnonKey
  ? createClient(supabaseUrl, supabaseAnonKey, { auth: { flowType: "pkce", persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } })
  : null;

// Capture recovery during SDK initialization, before React effects subscribe.
let verifiedRecoveryUserID: string | null = null;
supabase?.auth.onAuthStateChange((event, session) => {
  if (event === "PASSWORD_RECOVERY") verifiedRecoveryUserID = session?.user.id ?? null;
  else if (verifiedRecoveryUserID !== session?.user.id || event === "SIGNED_OUT" || event === "SIGNED_IN") verifiedRecoveryUserID = null;
});

type AuthContextValue = {
  user: User | null;
  session: Session | null;
  loading: boolean;
  recoveryVerified: boolean;
  configured: boolean;
  demoMode: boolean;
  signIn(email: string, password: string): Promise<string | null>;
  signUp(email: string, password: string, displayName: string, handle: string): Promise<string | null>;
  signOut(): Promise<void>;
  requestPasswordReset(email: string): Promise<string | null>;
  updatePassword(password: string): Promise<string | null>;
};

const demoUser = { id: "user-robert", email: "demo@liftrank.local", user_metadata: { display_name: "Robert J.", handle: "@rjrob23" } } as unknown as User;
const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: PropsWithChildren) {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(authDemoMode ? demoUser : null);
  const [loading, setLoading] = useState(Boolean(supabase));
  const [recoveryUserID, setRecoveryUserID] = useState<string | null>(verifiedRecoveryUserID);

  useEffect(() => {
    if (!supabase) { setLoading(false); return; }
    let active = true;
    void supabase.auth.getSession().then(({ data }) => { if (active) { setSession(data.session); setUser(data.session?.user ?? null); setLoading(false); } });
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession); setUser(nextSession?.user ?? null); setLoading(false);
      setRecoveryUserID(verifiedRecoveryUserID);
    });
    return () => { active = false; data.subscription.unsubscribe(); };
  }, []);

  const value = useMemo<AuthContextValue>(() => ({
    user, session, loading, recoveryVerified: Boolean(session && recoveryUserID === session.user.id), configured: Boolean(supabase), demoMode: authDemoMode,
    async signIn(email, password) {
      if (!supabase && authDemoMode) { if (email && password) { setUser(demoUser); return null; } return "Enter an email and password for the local demo."; }
      if (!supabase) return "Authentication is not configured.";
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      return error ? "Unable to sign in. Check your credentials and try again." : null;
    },
    async signUp(email, password, displayName, handle) {
      if (!supabase) return "Authentication is not configured.";
      const { error } = await supabase.auth.signUp({ email, password, options: { data: { display_name: displayName, handle: handle.startsWith("@") ? handle : `@${handle}` } } });
      return error ? error.message : null;
    },
    async signOut() {
      if (supabase) {
        const { error } = await supabase.auth.signOut({ scope: "local" });
        if (error) throw error;
      }
      if (supabase || authDemoMode) { setSession(null); setUser(null); setRecoveryUserID(null); }
    },
    async requestPasswordReset(email) {
      if (!supabase) return "Authentication is not configured.";
      const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}${window.location.pathname}#/reset-password` });
      return error ? error.message : null;
    },
    async updatePassword(password) {
      if (!supabase) return "Authentication is not configured.";
      const { data: current, error: sessionError } = await supabase.auth.getSession();
      if (sessionError || !current.session || verifiedRecoveryUserID !== current.session.user.id || current.session.user.id !== session?.user.id) return "Request a new reset link and open it in the same browser where you requested it.";
      if (password.length < 10) return "Use at least 10 characters for your password.";
      const { error } = await supabase.auth.updateUser({ password });
      if (!error) { verifiedRecoveryUserID = null; setRecoveryUserID(null); }
      return error ? error.message : null;
    }
  }), [loading, session, user, recoveryUserID]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth must be used inside AuthProvider");
  return value;
}
