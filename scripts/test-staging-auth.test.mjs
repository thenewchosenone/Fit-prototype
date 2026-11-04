import assert from 'node:assert/strict';
import test from 'node:test';
import { randomUUID } from 'node:crypto';
import { deleteDisposable, isDisposable, readConfig, runStagingAuth, STAGING_REF } from './test-staging-auth.mjs';

const jwt = (ref, role) => `test.${Buffer.from(JSON.stringify({ ref, role })).toString('base64url')}.test`;
const env = {
  STAGING_AUTH_URL: `https://${STAGING_REF}.supabase.co`,
  STAGING_AUTH_PUBLIC_KEY: jwt(STAGING_REF, 'anon'),
  STAGING_AUTH_SERVER_KEY: jwt(STAGING_REF, 'service_role')
};
const runId = 'a812a63c-814d-4517-9b6d-122b5e8ad341';
const user = {
  id: '552435da-26d7-4b8f-9023-0fcbb8c77081', email: `lr-auth-${runId}-a@example.test`,
  app_metadata: { test_suite: 'liftrivals-staging-auth-v1', test_run: runId }
};

test('accepts staging keys and rejects production, lookalike, and missing URLs', () => {
  assert.equal(readConfig(env).url, env.STAGING_AUTH_URL);
  for (const url of [undefined, 'https://ikjgbsrlriqiusuvezco.supabase.co', `${env.STAGING_AUTH_URL}.example.com`, `${env.STAGING_AUTH_URL}/`]) {
    assert.throws(() => readConfig({ ...env, STAGING_AUTH_URL: url }), /other projects are refused/);
  }
});

test('rejects missing, swapped, malformed, and wrong-project credentials without exposing them', () => {
  for (const value of ['', 'sensitive-credential-not-a-valid-key', jwt('ikjgbsrlriqiusuvezco', 'service_role'), env.STAGING_AUTH_PUBLIC_KEY]) {
    assert.throws(() => readConfig({ ...env, STAGING_AUTH_SERVER_KEY: value }), error => {
      assert.ok(!value || !error.message.includes(value));
      return /STAGING_AUTH_SERVER_KEY/.test(error.message);
    });
  }
  assert.throws(() => readConfig({ ...env, STAGING_AUTH_PUBLIC_KEY: env.STAGING_AUTH_SERVER_KEY }), /STAGING_AUTH_PUBLIC_KEY/);
});

test('allows opaque current key formats while keeping the destination fixed', () => {
  assert.ok(readConfig({ ...env, STAGING_AUTH_PUBLIC_KEY: 'sb_publishable_testing_key', STAGING_AUTH_SERVER_KEY: 'sb_secret_testing_key_123' }));
});

test('network entry point refuses a production destination before making requests', async () => {
  await assert.rejects(runStagingAuth({ ...readConfig(env), url: 'https://ikjgbsrlriqiusuvezco.supabase.co' }), /other projects are refused/);
});

test('cleanup requires an exact reserved address and server-owned suite/run marker', () => {
  assert.equal(isDisposable(user, runId), true);
  for (const candidate of [
    { ...user, email: 'real@example.com' },
    { ...user, email: user.email + '.example.com' },
    { ...user, app_metadata: {}, user_metadata: user.app_metadata },
    { ...user, app_metadata: { ...user.app_metadata, test_suite: 'another-suite' } },
    { ...user, app_metadata: { ...user.app_metadata, test_run: 'not-a-run-id' } },
    null
  ]) assert.equal(isDisposable(candidate, runId), false);
  assert.equal(isDisposable(user, 'c812a63c-814d-4517-9b6d-122b5e8ad341'), false);
});

test('cleanup never deletes a real account or an account belonging to a different run', async () => {
  for (const candidate of [{ ...user, email: 'real@example.com' }, { ...user, app_metadata: { ...user.app_metadata, test_run: 'other' } }, { ...user, id: 'wrong-id' }]) {
    let deleted = false;
    const admin = { getUserById: async () => ({ data: { user: candidate } }), deleteUser: async () => { deleted = true; } };
    await assert.rejects(deleteDisposable(admin, user.id, runId), /Refusing to delete/);
    assert.equal(deleted, false);
  }
});

test('cleanup verifies account absence after deleting the exact marked ID', async () => {
  let deleted = false;
  const admin = {
    getUserById: async () => deleted ? { error: { code: 'user_not_found', status: 404 } } : { data: { user } },
    deleteUser: async id => { assert.equal(id, user.id); deleted = true; return { data: {} }; }
  };
  await deleteDisposable(admin, user.id, runId);
  assert.equal(deleted, true);
});

test('cleanup surfaces deletion failures and does not mistake a server outage for absence', async () => {
  await assert.rejects(deleteDisposable({
    getUserById: async () => ({ data: { user } }),
    deleteUser: async () => ({ error: { code: 'unexpected_failure', message: 'secret value' } })
  }, user.id, runId), error => error.message === 'Delete disposable account: unexpected_failure');
  let reads = 0;
  await assert.rejects(deleteDisposable({
    getUserById: async () => ++reads === 1 ? { data: { user } } : { error: { status: 503 } },
    deleteUser: async () => ({ data: {} })
  }, user.id, runId), /Could not confirm/);
});

test('a failed live-test step still cleans both accounts through the real SDK', async t => {
  const accounts = new Map();
  const deleted = [];
  t.mock.method(console, 'log', () => {});
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    const request = new URL(url);
    assert.equal(request.origin, env.STAGING_AUTH_URL);
    const path = request.pathname;
    const reply = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'X-Supabase-Api-Version': '2024-01-01' } });
    if (path === '/auth/v1/admin/users' && init.method === 'GET') return reply({ users: [] });
    if (path === '/auth/v1/admin/users' && init.method === 'POST') {
      const body = JSON.parse(init.body);
      const created = { ...body, id: randomUUID(), created_at: new Date().toISOString() };
      accounts.set(created.id, created);
      return reply(created);
    }
    if (path === '/auth/v1/token') return reply({ code: 'unexpected_failure', msg: 'Sensitive error text must not be printed' }, 400);
    const id = path.split('/').at(-1);
    assert.ok(path.startsWith('/auth/v1/admin/users/'));
    if (init.method === 'DELETE') {
      assert.ok(accounts.has(id));
      deleted.push(id);
      accounts.delete(id);
      return reply({});
    }
    return accounts.has(id) ? reply(accounts.get(id)) : reply({ code: 'user_not_found', msg: 'Missing' }, 404);
  });
  await assert.rejects(runStagingAuth(readConfig(env)), error => error.message === 'Initial sign-in: unexpected_failure');
  assert.equal(deleted.length, 2);
  assert.equal(accounts.size, 0);
});

test('stale cleanup leaves recent, unmarked, and user-metadata-only accounts alone', async t => {
  const old = new Date(Date.now() - 2 * 86400000).toISOString();
  const stale = { ...user, created_at: old };
  const users = [stale,
    { ...user, id: 'recent', created_at: new Date().toISOString() },
    { ...user, id: 'real', email: 'real@example.com', created_at: old },
    { ...user, id: 'spoofed', app_metadata: {}, user_metadata: user.app_metadata, created_at: old }
  ];
  const deleted = [];
  t.mock.method(console, 'log', () => {});
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    const path = new URL(url).pathname;
    const reply = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'X-Supabase-Api-Version': '2024-01-01' } });
    if (path === '/auth/v1/admin/users') return reply({ users });
    assert.equal(path, `/auth/v1/admin/users/${stale.id}`);
    if (init.method === 'DELETE') { deleted.push(stale.id); return reply({}); }
    return deleted.length ? reply({ code: 'user_not_found' }, 404) : reply(stale);
  });
  await runStagingAuth(readConfig(env), { cleanupOnly: true });
  assert.deepEqual(deleted, [stale.id]);
});
