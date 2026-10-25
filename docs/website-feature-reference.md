# Lift Rivals Website Feature Reference

Last audited: 2026-07-16

This roadmap uses the Lift Rivals iOS app only as product inspiration for the website. The website remains an independent browser-local prototype. It does not synchronize accounts, workouts, messages, memberships, votes, settings, or any other data with the app.

Out of scope for this roadmap:

- App-to-website or website-to-app synchronization
- Shared account sessions or cross-device state
- Shared database tables, migrations, APIs, or service contracts
- Cross-client identifier reconciliation
- Moving browser-local activity into a production backend

Status definitions:

- **Missing** — the website does not yet offer the capability.
- **Prototype** — the capability works with seeded or browser-local data but needs product refinement.
- **Ready** — the browser-local experience is complete enough for the public demo and has automated coverage.

## Website capability roadmap

| Website capability | Current website state | Useful app reference | Remaining website-only work | Automated coverage | Status |
|---|---|---|---|---|---|
| Demo identity and access | Seeded local identity plus optional five-step browser-local onboarding | Onboarding structure and athlete-field organization | Continue usability review of first-run guidance | Web auth, demo and onboarding tests | Ready |
| Profiles and privacy | Athlete tabs, details, privacy controls and settings are browser-local | Profile hierarchy and privacy wording | Improve field editing and public/private previews | Web profile tests | Prototype |
| Profile photos | IndexedDB-backed select, circular crop, zoom, reposition, replace and remove workflow | Profile-photo interaction | Verify crop controls across Safari and mobile hardware | Media-store and UI tests | Ready |
| Gyms and memberships | Full local directory, primary gym and maximum-three enforcement | Primary-gym presentation | Refine empty, loading and retry states | Web reducer and UI tests | Ready |
| Friends | Local request lifecycle | Request-state labels and actions | Refine empty states and activity presentation | Web reducer and UI tests | Ready |
| Exercises and search | 244+ catalog with scored canonical/alias search, match reasons, multi-select filters and muscle images | Scored search, match reasons and detailed muscle maps | Finish remaining anatomical taxonomy review | Search logic and Library UI tests | Ready |
| Workout programs | Five immutable 12-week templates clone into editable local plans | Program structure and progression guidance | Add training-max entry and richer progression explanations | Web catalog, reducer and UI tests | Ready |
| Active workout tracking | Reordering, compatible substitutions, provenance, rest overrides, previous-set completion, keyboard flow, pause/resume and feedback | Reordering, substitution and completion flow | Continue real-device ergonomics review | Web reducer, UI and E2E tracker tests | Ready |
| Workout history and progress | History, calendar, volume, bodyweight, PRs and calculated streaks | History detail and completion insights | Add workout-detail route and richer completion summaries | Web reducer and UI tests | Prototype |
| Bodyweight | Dated browser-local records | Record-entry presentation | Improve chart controls and unit conversion tests | Web local-state tests | Prototype |
| Lift submissions and evidence | Browser-local submission and HTTPS media URL | Evidence-field organization | Improve validation and clearer demo-only labeling | Web submission tests | Prototype |
| Verification presentation | Evidence-oriented labels with Video Verified replacing Moderator Verified | Evidence-status vocabulary | Finish accessibility and tooltip review | Web migration and presentation tests | Ready |
| Leaderboards | Totals, filters, scopes, chips, pagination and preview labeling | Ranking explanations and row hierarchy | Continue responsive and accessibility refinement | Web platform and UI tests | Ready |
| Achievements | 21 stable activity-derived milestones with dates and progress | Milestone ideas and progress presentation | Tune milestone values after usability feedback | Catalog and derivation tests | Ready |
| Notifications | Structured local destinations for ranking, verification, friends, messages, forum, achievements and workout reminders | Destination presentation | Refine notification grouping and preference controls | Reducer and navigation tests | Ready |
| Training Groups | Groups, feeds, voting, threaded comments and moderation are browser-local | Community organization and safety copy | Refine moderation and mobile composition flows | Web forum tests | Ready |
| Messages | Local inbox, delete, report and thread actions | Thread organization | Refine deletion wording and empty states | Web messaging tests | Ready |
| Demonstration media | Bundled movement-family and main-lift media with labeling, pause/static mode, full screen and reduced-motion defaults | Movement-family and showcase-lift presentation | Validate full-screen behavior on physical Safari devices | UI and production-build coverage | Ready |

## Website product rules

These rules keep the browser experience internally consistent. They do not create an app synchronization contract.

| Rule | Website behavior |
|---|---|
| Exercise identity | Keep stable lowercase hyphenated IDs inside the website catalog. Display-name and alias edits do not change an existing website record ID. |
| Competition movements | Only approved website squat, bench and deadlift variants contribute to the displayed three-lift total. |
| Weight units | Convert between kilograms and pounds only at input and display boundaries; calculations use one normalized value. |
| DOTS | Calculate from bodyweight, sex category and the best eligible browser-local three-lift total. Label the result as a demo calculation. |
| Daily eligibility | Explain that leaderboard updates are simulated in the public demo and are not official rankings. |
| Verification labels | Competition Verified, Video Verified, Community Verified, Video Submitted and Self Reported. “Moderator Verified” remains retired. |
| Gym membership | Limit the browser-local profile to three joined gyms. A primary gym counts toward the limit. |
| Achievements | Use stable website-local IDs and derive unlocks from browser-local activity. |
| Program templates | Bundled definitions remain immutable and are cloned into an editable personal plan. |
| Demo storage | All reviewer activity stays in that browser and can be removed with Reset demo data. |

## Review policy

- App screens may inform website feature ideas and interaction quality, but they do not define shared data behavior.
- Every website feature must work with browser-local demo state and preserve Reset demo data.
- Do not add app synchronization, shared sessions, remote data calls, migrations, or backend dependencies under this roadmap.
- Keep platform-appropriate website navigation, accessibility and responsive behavior instead of copying native screens exactly.
- Public-demo builds must make zero Supabase requests.

## Next website work

1. Finish the remaining primary/secondary muscle taxonomy review.
2. Add richer workout-history detail and completion insight views.
3. Run the complete unit, demo, browser, performance, security-scan and production-build release gate.
4. Perform a final physical-device review of crop, full-screen media and active-workout ergonomics.
