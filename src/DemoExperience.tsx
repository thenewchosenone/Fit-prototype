import { useEffect, useRef, useState, type PropsWithChildren } from "react";
import { Link } from "react-router-dom";
import { Info, RotateCcw, ShieldCheck, X } from "lucide-react";
import { demoWelcomeStorageKey, publicDemoMode } from "./demo";
import { STORAGE_KEY } from "./store";
import { clearProfileMedia } from "./profileMedia";

export function DemoDataNotice({ children = "This activity is stored only in this browser and is not shared with other reviewers." }: PropsWithChildren) {
  if (!publicDemoMode) return null;
  return <aside className="demo-data-notice"><Info size={17} aria-hidden /><span><strong>Demo activity</strong>{children}</span></aside>;
}

function DemoDialog({ title, children, onClose }: PropsWithChildren<{ title: string; onClose: () => void }>) {
  const dialogRef = useRef<HTMLElement>(null);
  useEffect(() => {
    dialogRef.current?.focus();
    const close = (event: KeyboardEvent) => { if (event.key === "Escape") onClose(); };
    document.addEventListener("keydown", close);
    return () => document.removeEventListener("keydown", close);
  }, [onClose]);
  return <div className="modal-backdrop demo-modal-backdrop"><section ref={dialogRef} tabIndex={-1} className="modal demo-modal" role="dialog" aria-modal="true" aria-labelledby="demo-modal-title"><header><div><p className="eyebrow">Interactive sandbox</p><h2 id="demo-modal-title">{title}</h2></div><button className="icon-button" aria-label="Close demo information" onClick={onClose}><X /></button></header>{children}</section></div>;
}

export function DemoExperience() {
  const [welcomeOpen, setWelcomeOpen] = useState(() => publicDemoMode && localStorage.getItem(demoWelcomeStorageKey) !== "dismissed");
  const [resetOpen, setResetOpen] = useState(false);
  if (!publicDemoMode) return null;

  const dismissWelcome = () => {
    localStorage.setItem(demoWelcomeStorageKey, "dismissed");
    setWelcomeOpen(false);
  };
  const resetDemo = () => {
    localStorage.removeItem(STORAGE_KEY);
    localStorage.removeItem(demoWelcomeStorageKey);
    void clearProfileMedia().finally(() => window.location.reload());
  };

  return <>
    <aside className="demo-banner" aria-label="Public demo notice"><span><ShieldCheck size={16} aria-hidden /><strong>LiftRank Demo</strong><small>Changes stay in this browser.</small></span><nav aria-label="Demo links"><Link to="/demo">About</Link><Link to="/privacy">Privacy</Link><Link to="/terms">Terms</Link><Link to="/contact">Feedback</Link><button onClick={() => setResetOpen(true)}><RotateCcw size={14} /> Reset</button></nav></aside>
    {welcomeOpen && <DemoDialog title="Explore LiftRank" onClose={dismissWelcome}><div className="demo-welcome-copy"><p>Review the complete LiftRank experience: compare rankings, submit lifts, browse exercises and gyms, join Training Groups, send messages, and edit the seeded athlete profile.</p><div className="demo-welcome-grid"><span><strong>Fully interactive</strong><small>Use every feature with seeded demo data.</small></span><span><strong>Browser-local</strong><small>Nothing you enter is sent to a LiftRank backend.</small></span><span><strong>Not a real account</strong><small>Everyone begins as the Robert J. demo athlete.</small></span></div><div className="dialog-actions"><Link className="quiet-button" to="/demo" onClick={dismissWelcome}>Learn about the demo</Link><button className="primary-button" onClick={dismissWelcome}>Start exploring</button></div></div></DemoDialog>}
    {resetOpen && <DemoDialog title="Reset the LiftRank demo?" onClose={() => setResetOpen(false)}><div className="demo-welcome-copy"><p>This removes every lift, message, vote, membership, filter, and profile change stored by LiftRank in this browser, then restores the original demo.</p><div className="dialog-actions"><button className="quiet-button" onClick={() => setResetOpen(false)}>Cancel</button><button className="danger-button" onClick={resetDemo}>Reset demo data</button></div></div></DemoDialog>}
  </>;
}
