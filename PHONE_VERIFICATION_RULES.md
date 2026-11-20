# Phone Verification Rules

Use these rules while verifying Lift Rivals fixes:

- Use the user's connected iPhone as the only device. Use a simulator only when the user explicitly asks.
- Check the current phone screen before taking an action. Do not switch devices or modes on your own.
- Do not end a phone check after one failed tap. Reacquire the mirroring window and retry; report a control blocker only after repeated attempts fail, and continue the checklist whenever control returns.
- Track each requested fix separately as implemented, verified on the phone, or blocked.
- If user action is needed, state exactly what is needed and wait. Do not guess credentials or change accounts.
- Before asking the user to sign in, verify that the installed build targets the backend where their account exists. Debug may use staging while Release/TestFlight uses production; never ask them to retry credentials against an unverified environment.
- For TestFlight uploads, when the user asks for an alternative to Xcode Organizer's Distribute flow, use an available command-line or Transporter path. Confirm the intended build and destination first; if required App Store Connect credentials are unavailable, report that instead of switching upload methods without explanation.

## Recorded incident

- Build 42 Debug targeted staging, but the user's account was on production. This caused a correct password to be rejected. Build 42 Release targeted production and restored the signed-in account. Check build configuration and backend environment before future sign-in troubleshooting.
