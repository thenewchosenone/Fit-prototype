import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ownedLiftEvidenceCleanupPaths, profileAvatarCleanupPaths } from "../_shared/account-storage-paths.js";
import { hasRecentAuthentication } from "../_shared/recent-authentication.js";
import { selectAllRows } from "../_shared/paginated-select.js";
import { removeStoragePathsInBatches } from "../_shared/storage-cleanup.js";

const allowedOrigins = new Set(["https://liftrivals.com", "https://www.liftrivals.com"]);
const headersFor = (origin: string | null) => ({
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  ...(origin && allowedOrigins.has(origin)
    ? { "Access-Control-Allow-Origin": origin, Vary: "Origin" }
    : {}),
});

const json = (body: Record<string, unknown>, status: number, origin: string | null) => new Response(
  JSON.stringify(body),
  { status, headers: { ...headersFor(origin), "Content-Type": "application/json" } },
);

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: headersFor(origin) });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405, origin);
  const authorization = request.headers.get("Authorization") ?? "";
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "Server configuration missing" }, 500, origin);

  const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return json({ error: "Unauthorized" }, 401, origin);

  const accessToken = authorization.replace(/^Bearer\s+/i, "");
  // getUser above validates the JWT signature. Its iat is not an authentication
  // timestamp because Supabase issues a new access token when refreshing.
  if (!hasRecentAuthentication(accessToken)) {
    return json({ error: "Recent authentication required" }, 403, origin);
  }

  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  // Database rows use ON DELETE CASCADE from auth-owned profiles. Delete private
  // media first because Storage objects are not covered by database cascades.
  const { data: assets, error: assetError } = await selectAllRows(() => admin.from("lift_media_assets")
    .select("storage_path")
    .eq("owner_id", user.id)
    .order("storage_path"));
  if (assetError) return json({ error: "Media cleanup lookup failed" }, 500, origin);

  const { data: submissions, error: submissionError } = await selectAllRows(() => admin.from("lift_submissions")
    .select("id,evidence_storage_path,pending_evidence_storage_path,approved_evidence_storage_path")
    .eq("user_id", user.id)
    .order("id"));
  if (submissionError) return json({ error: "Evidence cleanup lookup failed" }, 500, origin);

  const storagePaths = new Map<string, Set<string>>();
  const addStoragePaths = (bucket: string, paths: string[]) => {
    const existing = storagePaths.get(bucket) ?? new Set<string>();
    paths.filter((path) => path.length > 0).forEach((path) => existing.add(path));
    if (existing.size) storagePaths.set(bucket, existing);
  };
  addStoragePaths("lift-videos", (assets ?? []).map((asset) => asset.storage_path));

  const legacyEvidencePaths = (submissions ?? []).flatMap((submission) =>
    ownedLiftEvidenceCleanupPaths(user.id, submission.id, [
      submission.evidence_storage_path,
      submission.pending_evidence_storage_path,
      submission.approved_evidence_storage_path,
    ]),
  );
  if (legacyEvidencePaths.length) {
    const { data: buckets, error: bucketError } = await admin.storage.listBuckets();
    if (bucketError) return json({ error: "Evidence storage lookup failed" }, 500, origin);
    for (const bucket of (buckets ?? []).filter((candidate) => candidate.id.startsWith("lift-evidence"))) {
      addStoragePaths(bucket.id, legacyEvidencePaths);
    }
  }

  for (const [bucket, paths] of storagePaths) {
    const storageError = await removeStoragePathsInBatches(admin.storage, bucket, [...paths]);
    if (storageError) return json({ error: "Media cleanup failed" }, 500, origin);
  }

  const { data: profile, error: profileError } = await admin.from("profiles").select("avatar_path").eq("id", user.id).maybeSingle();
  if (profileError) return json({ error: "Profile cleanup lookup failed" }, 500, origin);
  if (profile?.avatar_path) {
    const avatarError = await removeStoragePathsInBatches(
      admin.storage,
      "profile-avatars",
      profileAvatarCleanupPaths(user.id, profile.avatar_path),
    );
    if (avatarError) return json({ error: "Avatar cleanup failed" }, 500, origin);
  }
  const { error: deletionError } = await admin.auth.admin.deleteUser(user.id, false);
  if (deletionError) return json({ error: "Deletion failed" }, 500, origin);
  return new Response(null, { status: 204, headers: headersFor(origin) });
});
