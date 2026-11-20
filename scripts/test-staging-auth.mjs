import { randomBytes, randomUUID } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { createClient } from '@supabase/supabase-js';

export const STAGING_REF = 'dfpvamnucwyafxklnjwt';
const STAGING_URL = `https://${STAGING_REF}.supabase.co`;
const SUITE = 'liftrivals-staging-auth-v1';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
class TestFailure extends Error {}

function requireCondition(condition, message) {
  if (!condition) throw new TestFailure(message);
}

export function readConfig(env) {
  requireCondition(env.STAGING_AUTH_URL === STAGING_URL,
    `STAGING_AUTH_URL must be exactly ${STAGING_URL}; other projects are refused.`);
  for (const [name, role, prefix] of [
    ['STAGING_AUTH_PUBLIC_KEY', 'anon', 'sb_publishable_'],
    ['STAGING_AUTH_SERVER_KEY', 'service_role', 'sb_secret_']
  ]) {
    const key = env[name];
    requireCondition(typeof key === 'string' && key.length > 20, `${name} is missing.`);
    if (key.startsWith(prefix)) continue;
    let payload;
    try { payload = JSON.parse(Buffer.from(key.split('.')[1], 'base64url').toString()); } catch { /* Rejected below. */ }
    requireCondition(payload?.ref === STAGING_REF && payload?.role === role,
      `${name} must belong to the staging project and have the expected role.`);
  }
  return { url: STAGING_URL, publicKey: env.STAGING_AUTH_PUBLIC_KEY, serverKey: env.STAGING_AUTH_SERVER_KEY };
}

export function isDisposable(user, runId) {
  const run = user?.app_metadata?.test_run;
  return Boolean(UUID.test(run ?? '') && (!runId || run === runId)
    && user.app_metadata.test_suite === SUITE
    && ['a', 'b'].some(label => user.email === `lr-auth-${run}-${label}@example.test`));
}

function ok(result, label) {
  // Do not print SDK errors, request bodies, passwords, links, or sessions.
  if (result.error) {
    const code = /^[a-z_]+$/.test(result.error.code ?? '') ? result.error.code : 'request_failed';
    throw new TestFailure(`${label}: ${code}`);
  }
  return result.data;
}

export async function deleteDisposable(admin, id, runId) {
  const { user } = ok(await admin.getUserById(id), 'Read cleanup account');
  requireCondition(user?.id === id && isDisposable(user, runId), 'Refusing to delete an unmarked account.');
  ok(await admin.deleteUser(id), 'Delete disposable account');
  const absent = await admin.getUserById(id);
  requireCondition(absent.error?.code === 'user_not_found' || absent.error?.status === 404,
    'Could not confirm disposable account deletion.');
}

async function cleanStale(admin) {
  const stale = [];
  for (let page = 1; ; page++) {
    const { users } = ok(await admin.listUsers({ page, perPage: 100 }), 'List stale test accounts');
    for (const user of users) {
      if (isDisposable(user) && Date.parse(user.created_at) < Date.now() - 86400000) stale.push(user);
    }
    if (users.length < 100) break;
  }
  // Collect first: deleting while paging could skip accounts.
  for (const user of stale) await deleteDisposable(admin, user.id, user.app_metadata.test_run);
  console.log(`Cleaned ${stale.length} marked test accounts older than 24 hours.`);
}

export async function runStagingAuth(config, { cleanupOnly = false } = {}) {
  // Revalidate at the network boundary, including callers importing this module.
  readConfig({ STAGING_AUTH_URL: config.url, STAGING_AUTH_PUBLIC_KEY: config.publicKey, STAGING_AUTH_SERVER_KEY: config.serverKey });
  const makeClient = key => createClient(config.url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false, storageKey: randomUUID() },
    global: { fetch: (url, init) => {
      requireCondition(new URL(url).origin === STAGING_URL, 'Refusing a request outside staging.');
      return fetch(url, { ...init, redirect: 'error', signal: AbortSignal.timeout(15000) });
    } }
  });
  const admin = makeClient(config.serverKey).auth.admin;
  await cleanStale(admin);
  if (cleanupOnly) return;
  const runId = randomUUID();
  const accounts = [];
  const clients = [];
  const fresh = () => { const client = makeClient(config.publicKey).auth; clients.push(client); return client; };
  const password = () => `Aa1!${randomBytes(24).toString('base64url')}`;
  const expectError = (result, code, label) => requireCondition(result.error?.code === code, `${label}: expected ${code}.`);
  let failure;
  console.log(`Staging auth run ${runId} (API recovery; no email delivery or UI coverage).`);
  try {
    for (const label of ['a', 'b']) {
      const email = `lr-auth-${runId}-${label}@example.test`;
      const initialPassword = password();
      const { user } = ok(await admin.createUser({
        email, password: initialPassword, email_confirm: true,
        app_metadata: { test_suite: SUITE, test_run: runId },
        user_metadata: { display_name: 'Disposable Auth Test' }
      }), 'Create disposable account');
      requireCondition(Boolean(user?.id), 'Account creation returned no ID.');
      accounts.push({ id: user.id, email, initialPassword });
      requireCondition(isDisposable(user, runId), 'Created account is missing its cleanup marker.');
    }
    console.log('PASS: two marked disposable accounts created.');
    const [a, b] = accounts;
    const client = fresh();
    const anonymousUpdate = await client.updateUser({ password: password() });
    requireCondition(anonymousUpdate.error?.name === 'AuthSessionMissingError', 'Password update without a session was not rejected.');
    const first = ok(await client.signInWithPassword({ email: a.email, password: a.initialPassword }), 'Initial sign-in');
    requireCondition(first.user?.id === a.id, 'Initial sign-in returned the wrong account.');
    const refreshed = ok(await client.refreshSession(), 'Refresh session');
    requireCondition(refreshed.user?.id === a.id, 'Session refresh returned the wrong account.');
    ok(await client.signOut({ scope: 'local' }), 'Sign out');
    expectError(await client.signInWithPassword({ email: a.email, password: password() }), 'invalid_credentials', 'Wrong password');
    console.log('PASS: sign-in, refresh, sign-out, and wrong-password rejection.');

    const link = ok(await admin.generateLink({ type: 'recovery', email: a.email }), 'Generate recovery token');
    const tokenHash = link.properties?.hashed_token;
    requireCondition(link.user?.id === a.id && typeof tokenHash === 'string' && tokenHash.length > 0, 'Recovery token returned the wrong account or no token.');
    expectError(await client.verifyOtp({ type: 'recovery', token_hash: randomBytes(32).toString('hex') }), 'otp_expired', 'Invalid recovery token');
    const events = [];
    const { data: { subscription } } = client.onAuthStateChange(event => { events.push(event); });
    try {
      const recovered = ok(await client.verifyOtp({ type: 'recovery', token_hash: tokenHash }), 'Verify recovery token');
      requireCondition(recovered.user?.id === a.id && events.includes('PASSWORD_RECOVERY'), 'Verified recovery did not emit the expected account event.');
    } finally { subscription.unsubscribe(); }
    expectError(await client.updateUser({ password: 'a' }), 'weak_password', 'Weak password');
    const newPassword = password();
    const updated = ok(await client.updateUser({ password: newPassword }), 'Update recovered password');
    requireCondition(updated.user?.id === a.id, 'Password update returned the wrong account.');
    expectError(await fresh().verifyOtp({ type: 'recovery', token_hash: tokenHash }), 'otp_expired', 'Reused recovery token');
    ok(await client.signOut({ scope: 'local' }), 'Sign out after reset');
    expectError(await fresh().signInWithPassword({ email: a.email, password: a.initialPassword }), 'invalid_credentials', 'Old password after reset');
    const signedIn = ok(await fresh().signInWithPassword({ email: a.email, password: newPassword }), 'New-password sign-in');
    requireCondition(signedIn.user?.id === a.id && signedIn.session, 'New-password sign-in did not authenticate the expected account.');
    const restored = fresh();
    ok(await restored.setSession({ access_token: signedIn.session.access_token, refresh_token: signedIn.session.refresh_token }), 'Restore session into fresh SDK client');
    requireCondition(ok(await restored.getUser(), 'Validate restored session').user?.id === a.id, 'Restored session belongs to the wrong account.');
    console.log('PASS: recovery event, weak-password rejection, password reset, one-time token, old/new passwords, SDK session restoration.');

    const other = fresh();
    requireCondition(ok(await other.signInWithPassword({ email: b.email, password: b.initialPassword }), 'Second-account sign-in').user?.id === b.id, 'Second account changed during recovery.');
    expectError(await other.verifyOtp({ type: 'recovery', token_hash: tokenHash }), 'otp_expired', 'Reused token with another account signed in');
    requireCondition(ok(await other.getUser(), 'Validate unaffected account').user?.id === b.id, 'Invalid recovery changed the second account.');
    console.log('PASS: second account unchanged after invalid recovery.');
  } catch (error) {
    failure = error;
  } finally {
    for (const client of clients) client.stopAutoRefresh();
    // Attempt every cleanup even when one deletion fails; never report a clean pass in that case.
    for (const account of accounts) {
      try { await deleteDisposable(admin, account.id, runId); }
      catch { console.error(`CLEANUP FAILED: marked account ${account.id}; retry cleanup after 24 hours.`); failure ??= new TestFailure('Disposable account cleanup failed.'); }
    }
  }
  if (failure) throw failure;
  console.log('PASS: all disposable accounts deleted and absence verified.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const args = process.argv.slice(2);
    requireCondition(args.every(arg => ['--check', '--cleanup-stale'].includes(arg)), 'Unknown option. Use --check or --cleanup-stale.');
    const config = readConfig(process.env);
    if (args.includes('--check')) console.log(`Configuration validated for ${STAGING_REF}; no network requests made.`);
    else await runStagingAuth(config, { cleanupOnly: args.includes('--cleanup-stale') });
  } catch (error) {
    // Only our explicit messages are safe to print; SDK/network exceptions can contain secrets.
    console.error(error instanceof TestFailure ? error.message : 'Staging auth test failed; inspect staging Auth logs without exposing credentials.');
    process.exitCode = 1;
  }
}
