import assert from "node:assert/strict";
import test from "node:test";

import { isTransientPushFailure, shouldMarkApnsDeliveryComplete } from "./notification-delivery.js";

test("push delivery retries network, throttling, and provider-auth failures", () => {
  for (const status of [0, 401, 403, 408, 429, 500, 503]) {
    assert.equal(isTransientPushFailure(status), true, `status ${status} should remain retryable`);
  }
});

test("push delivery treats invalid endpoints and payloads as terminal", () => {
  for (const status of [400, 404, 410, 413, 422]) {
    assert.equal(isTransientPushFailure(status), false, `status ${status} should not retry forever`);
  }
});

test("one successful APNs device completes delivery despite another transient failure", () => {
  assert.equal(shouldMarkApnsDeliveryComplete(true, true), true);
});

test("APNs delivery retries only when no device succeeded and a transient failure remains", () => {
  assert.equal(shouldMarkApnsDeliveryComplete(false, true), false);
  assert.equal(shouldMarkApnsDeliveryComplete(false, false), true);
});
