import assert from "node:assert/strict";
import test from "node:test";

import { selectAllRows } from "./paginated-select.js";

test("selects every row in stable bounded pages", async () => {
  const rows = Array.from({ length: 1201 }, (_, id) => ({ id }));
  const ranges = [];

  const result = await selectAllRows(() => ({
    async range(from, to) {
      ranges.push([from, to]);
      return { data: rows.slice(from, to + 1), error: null };
    },
  }));

  assert.deepEqual(ranges, [[0, 499], [500, 999], [1000, 1499]]);
  assert.deepEqual(result.data, rows);
  assert.equal(result.error, null);
});

test("stops and returns the first page error", async () => {
  const failure = new Error("temporary database failure");
  const ranges = [];

  const result = await selectAllRows(() => ({
    async range(from, to) {
      ranges.push([from, to]);
      return from === 0
        ? { data: Array.from({ length: 500 }, (_, id) => ({ id })), error: null }
        : { data: null, error: failure };
    },
  }));

  assert.deepEqual(ranges, [[0, 499], [500, 999]]);
  assert.equal(result.data, null);
  assert.equal(result.error, failure);
});
