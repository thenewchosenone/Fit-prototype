import assert from "node:assert/strict";
import test from "node:test";

import { ownedLiftEvidenceCleanupPaths, profileAvatarCleanupPaths } from "./account-storage-paths.js";

test("avatar cleanup derives paths from the authenticated owner, not the stored path", () => {
  const ownerID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
  const victimID = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";

  assert.deepEqual(
    profileAvatarCleanupPaths(ownerID, `${victimID}/avatar`),
    [
      `${ownerID}/avatar/avatar-full.jpg`,
      `${ownerID}/avatar/avatar-thumb.jpg`,
    ],
  );
});

test("avatar cleanup skips accounts with no stored avatar path", () => {
  assert.deepEqual(profileAvatarCleanupPaths("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", null), []);
  assert.deepEqual(profileAvatarCleanupPaths("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", ""), []);
});

test("lift evidence cleanup accepts only paths in the authenticated owner's lift namespace", () => {
  const ownerID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
  const victimID = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
  const liftID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";

  assert.deepEqual(
    ownedLiftEvidenceCleanupPaths(ownerID, liftID, [
      `${ownerID}/${liftID}/evidence.mp4`,
      `${victimID}/${liftID}/evidence.mp4`,
      `${ownerID}/other-lift/evidence.mp4`,
      `${ownerID}/${liftID}/../${victimID}/evidence.mp4`,
      `${ownerID}/${liftID}/evidence.mp4`,
    ]),
    [`${ownerID}/${liftID}/evidence.mp4`],
  );
});

