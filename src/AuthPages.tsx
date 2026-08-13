import { Check, LockKeyhole, LogIn, ShieldCheck } from "lucide-react";
import { type FormEvent, useState } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "./auth";

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  const location = useLocation();
  if (loading) return <div className="auth-loading" role="status">Checking your session…</div>;
  if (!user) return <Navigate to="/login" replace state={{ from: `${location.pathname}${location.search}` }} />;
  return children;
}

type AuthMode = "login" | "signup" | "forgot" | "reset";

export function AuthPage({ mode }: { mode: AuthMode }) {
  const auth = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [handle, setHandle] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const from = (location.state as { from?: string } | null)?.from ?? "/leaderboards";

  if (auth.user && mode === "login") return <Navigate to={from} replace />;

  const submit = async (event: FormEvent) => {
    event.preventDefault(); setError(null); setMessage(null); setSubmitting(true);
    let nextError: string | null = null;
    if (mode === "login") nextError = await auth.signIn(email, password);
    if (mode === "signup") nextError = await auth.signUp(email, password, displayName, handle);
    if (mode === "forgot") nextError = await auth.requestPasswordReset(email);
    if (mode === "reset") nextError = await auth.updatePassword(password);
    setSubmitting(false);
    if (nextError) { setError(nextError); return; }
    if (mode === "login" || mode === "reset") navigate(mode === "login" ? from : "/settings", { replace: true });
    else setMessage(mode === "signup" ? "Check your email to verify your Lift Rivals account." : "If the address is registered, a reset link has been sent.");
  };

  const copy = {
    login: ["Welcome back", "Sign in to submit lifts, join groups, and manage your profile."],
    signup: ["Create your account", "Build a verified strength profile and join the community."],
    forgot: ["Reset your password", "We’ll email a secure recovery link if the account exists."],
    reset: ["Choose a new password", "Use a strong password you do not reuse elsewhere."]
  }[mode];

  return <div className="auth-page"><section className="auth-brand-panel"><span className="auth-mark">LR</span><p className="eyebrow">Lift Rivals security</p><h1>Train publicly.<br />Protect your account.</h1><div className="auth-benefits"><span><ShieldCheck /> Server-enforced permissions</span><span><LockKeyhole /> Private messages and lifts</span><span><Check /> Verified account recovery</span></div></section><main className="auth-card"><div><p className="eyebrow">Account</p><h2>{copy[0]}</h2><p>{copy[1]}</p></div>{!auth.configured && <div className="auth-config-warning"><strong>{auth.demoMode ? "Local demo mode" : "Authentication setup required"}</strong><span>{auth.demoMode ? "The seeded prototype account is active. Add Supabase environment values to test real accounts." : "Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY before enabling account access."}</span></div>}<form onSubmit={submit}>{mode === "signup" && <><label><span>Display name</span><input required autoComplete="name" value={displayName} onChange={(event) => setDisplayName(event.target.value)} /></label><label><span>Handle</span><input required autoComplete="username" value={handle} onChange={(event) => setHandle(event.target.value)} placeholder="@handle" /></label></>}{mode !== "reset" && <label><span>Email</span><input required type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} /></label>}{mode !== "forgot" && <label><span>{mode === "reset" ? "New password" : "Password"}</span><input required type="password" minLength={10} autoComplete={mode === "login" ? "current-password" : "new-password"} value={password} onChange={(event) => setPassword(event.target.value)} /><small>At least 10 characters.</small></label>}{error && <p className="auth-error" role="alert">{error}</p>}{message && <p className="auth-success" role="status">{message}</p>}<button className="primary-button large full-width" disabled={submitting}>{mode === "login" && <LogIn size={18} />}{submitting ? "Please wait…" : mode === "login" ? "Sign in" : mode === "signup" ? "Create account" : mode === "forgot" ? "Send reset link" : "Update password"}</button></form><footer>{mode === "login" && <><Link to="/forgot-password">Forgot password?</Link><span>New to Lift Rivals? <Link to="/signup">Create account</Link></span></>}{mode === "signup" && <span>Already have an account? <Link to="/login">Sign in</Link></span>}{(mode === "forgot" || mode === "reset") && <Link to="/login">Back to sign in</Link>}</footer></main></div>;
}
