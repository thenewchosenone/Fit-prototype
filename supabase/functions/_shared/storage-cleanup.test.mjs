import assert from "node:assert/strict";
import test from "node:test";

import { removeStoragePathsInBatches } from "./storage-cleanup.js";

test("storage cleanup removes at most 1000 paths per request", async () => {
  const calls = [];
  const storage = {
    from(bucket) {
      return {
        async remove(paths) {
          calls.push({ bucket, paths });
          return { error: null };
        },
      };
    },
  };
  const paths = Array.from({ length: 2001 }, (_, index) => `owner/lift/${index}.mp4`);

  assert.equal(await removeStoragePathsInBatches(storage, "lift-videos", paths), null);
  assert.deepEqual(calls.map(({ paths: batch }) => batch.length), [1000, 1000, 1]);
  assert.deepEqual(calls.flatMap(({ paths: batch }) => batch), paths);
  assert.ok(calls.every(({ bucket }) => bucket === "lift-videos"));
});

test("storage cleanup stops on the first failed batch for safe retry", async () => {
  const failure = new Error("temporary storage failure");
  const calls = [];
  const storage = {
    from() {
      return {
        async remove(paths) {
          calls.push(paths.length);
          return { error: calls.length === 2 ? failure : null };
        },
      };
    },
  };

  assert.equal(
    await removeStoragePathsInBatches(storage, "lift-videos", Array.from({ length: 2500 }, (_, index) => `${index}.mp4`)),
    failure,
  );
  assert.deepEqual(calls, [1000, 1000]);
});
