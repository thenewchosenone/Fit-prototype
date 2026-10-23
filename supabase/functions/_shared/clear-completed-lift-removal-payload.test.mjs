import assert from "node:assert/strict";
import test from "node:test";

import { clearCompletedLiftRemovalPayload } from "./clear-completed-lift-removal-payload.js";

test("clears private recovery payload only for a completed request", async () => {
  const calls = [];
  const database = {
    from(table) {
      calls.push({ table });
      return {
        update(values) {
          calls.push({ values });
          return {
            eq(column, value) {
              calls.push({ column, value });
              return this;
            },
            select(columns) {
              calls.push({ columns });
              return this;
            },
            async maybeSingle() {
              return { data: { id: "request-1" }, error: null };
            },
          };
        },
      };
    },
  };

  assert.equal(await clearCompletedLiftRemovalPayload(database, "request-1"), null);
  assert.deepEqual(calls, [
    { table: "lift_removal_requests" },
    { values: { lift_snapshot: {}, storage_objects: [] } },
    { column: "id", value: "request-1" },
    { column: "status", value: "completed" },
    { columns: "id" },
  ]);
});

test("returns cleanup errors so the completed request can be retried", async () => {
  const failure = new Error("temporary database error");
  const database = {
    from() {
      return {
        update() {
          return {
            eq() { return this; },
            select() { return this; },
            async maybeSingle() { return { data: null, error: failure }; },
          };
        },
      };
    },
  };

  assert.equal(await clearCompletedLiftRemovalPayload(database, "request-1"), failure);
});

test("reports a missing completed row instead of claiming payload cleanup", async () => {
  const database = {
    from() {
      return {
        update() {
          return {
            eq() { return this; },
            select() { return this; },
            async maybeSingle() { return { data: null, error: null }; },
          };
        },
      };
    },
  };

  const error = await clearCompletedLiftRemovalPayload(database, "request-1");
  assert.match(error?.message ?? "", /not found/);
});
