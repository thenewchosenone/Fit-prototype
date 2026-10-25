# LiftRank publish-readiness evidence

Run ID: mandatory-refresh-20260905
Run date: Sat Sep  5 22:10:50 EDT 2026
Working directory: /Users/robertjeanty/Documents/ChatGPT/Lift Rivals App

## Environment

- Web gates enabled: 0
- iOS gates enabled: 0
- Backend gates enabled: 1
- Strict mode: 0
- Timeout per step (s): 1800

## Source state

- Revision: b4e3d9963c720e41c76916b7774d209eb747d065
- Working tree: dirty
- Full status: /Users/robertjeanty/Documents/ChatGPT/Lift Rivals App/release-evidence/mandatory-refresh-20260905/source-state.txt
[2026-09-05 22:10:50] PASS: baseline iOS scheme present: LiftRank
\n[2026-09-05 22:10:50] START: publish_readiness.services
[2026-09-05 22:10:50] PASS: publish_readiness.services (log: /Users/robertjeanty/Documents/ChatGPT/Lift Rivals App/release-evidence/mandatory-refresh-20260905/ios-services-readiness.log)
\n[2026-09-05 22:10:50] START: publish_readiness.app_store_metadata
[2026-09-05 22:10:50] PASS: publish_readiness.app_store_metadata (log: /Users/robertjeanty/Documents/ChatGPT/Lift Rivals App/release-evidence/mandatory-refresh-20260905/app-store-metadata-readiness.log)
Web gates disabled via RUN_WEB_FRONTEND_GATES=0
iOS gates disabled via RUN_IOS_GATES=0
\n[2026-09-05 22:10:50] START: backend.pg_tap_suite
[2026-09-05 22:10:50] PASS: backend.pg_tap_suite (log: /Users/robertjeanty/Documents/ChatGPT/Lift Rivals App/release-evidence/mandatory-refresh-20260905/backend-pgtap.log)

## Gate summary
- pass: 4
- fail: 0
- skip: 0
- status: PASS
\nGate evidence written to: /Users/robertjeanty/Documents/ChatGPT/Lift Rivals App/release-evidence/mandatory-refresh-20260905/release-evidence.md
Machine-readable summary: /Users/robertjeanty/Documents/ChatGPT/Lift Rivals App/release-evidence/mandatory-refresh-20260905/summary.txt
PASS: all automated gates completed.
