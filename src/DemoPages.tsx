import { ExternalLink, Github, ShieldCheck } from "lucide-react";
import { Link } from "react-router-dom";

const feedbackUrl = "https://github.com/thenewchosenone/Fit-prototype/issues/new";

function InfoLayout({ eyebrow, title, intro, children }: React.PropsWithChildren<{ eyebrow: string; title: string; intro: string }>) {
  return <div className="page narrow-page info-page"><header className="page-header"><div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1><p>{intro}</p></div></header><div className="info-card">{children}</div><nav className="legal-nav" aria-label="Demo information"><Link to="/demo">Demo info</Link><Link to="/privacy">Privacy</Link><Link to="/terms">Terms</Link><Link to="/contact">Contact</Link></nav></div>;
}

export function DemoInfoPage() {
  return <InfoLayout eyebrow="Interactive sandbox" title="About this LiftRank demo" intro="A complete product preview powered by seeded, browser-local data."><h2>What you can explore</h2><p>Compare strength rankings, submit a demonstration lift, browse 268 exercises, search the gym directory, join Training Groups, vote and comment, send seeded messages, and customize the Robert J. athlete profile.</p><h2>How the sandbox works</h2><p>Your activity is saved only in this browser. It is not shared with other reviewers, synchronized to another device, or stored in a LiftRank database. Reset restores the original experience at any time.</p><div className="info-callout"><ShieldCheck /><span><strong>No production account</strong><small>This demo is for product review and usability testing, not real training records or private communication.</small></span></div></InfoLayout>;
}

export function PrivacyPage() {
  return <InfoLayout eyebrow="Public demo" title="Privacy notice" intro="Effective July 13, 2026 for the LiftRank browser-local demonstration."><h2>Information stored by LiftRank</h2><p>Demo changes are stored in your browser using localStorage. LiftRank does not operate an account or activity database for this demo and does not receive your lifts, messages, votes, memberships, or profile edits.</p><h2>Hosting</h2><p>Cloudflare Pages serves the site and may process ordinary request information such as IP address, browser details, requested files, and security events under Cloudflare’s policies.</p><h2>Feedback</h2><p>If you open a GitHub issue, GitHub receives the information you choose to submit under your GitHub account and its privacy policy. Do not include health information, private messages, passwords, or other sensitive data.</p><h2>Removing demo data</h2><p>Use Reset in the demo banner or clear this site’s browser storage.</p></InfoLayout>;
}

export function TermsPage() {
  return <InfoLayout eyebrow="Public demo" title="Demo terms" intro="Use this sandbox only to evaluate the LiftRank product experience."><h2>Non-production service</h2><p>The demo is provided as-is. Data can be reset, changed, or removed without notice. Rankings, memberships, verification labels, messages, and community activity are illustrative and are not claims about real people or gym operators.</p><h2>Fitness disclaimer</h2><p>LiftRank content is general information and personal experience, not medical advice, diagnosis, or individualized training instruction. Consult a qualified professional before changing exercise, nutrition, or recovery practices.</p><h2>Acceptable use</h2><p>Do not enter sensitive information, attempt to disrupt the service, probe third-party infrastructure, impersonate another person, or rely on the sandbox for recordkeeping.</p></InfoLayout>;
}

export function ContactPage() {
  return <InfoLayout eyebrow="Feedback" title="Help shape LiftRank" intro="Report a bug, usability problem, or product suggestion without exposing a personal email address."><h2>Before submitting</h2><p>Describe what you expected, what happened, the device or browser you used, and the page where you noticed it. Do not include passwords, private messages, health information, or other sensitive details.</p><a className="primary-button info-feedback-link" href={feedbackUrl} target="_blank" rel="noreferrer"><Github size={18} /> Open GitHub feedback <ExternalLink size={15} /></a></InfoLayout>;
}
