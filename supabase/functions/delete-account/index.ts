import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

  const payloadSegment = authorization.replace(/^Bearer\s+/i, "").split(".")[1] ?? "";
  let issuedAt = Number.NaN;
  try {
    const normalized = payloadSegment.replaceAll("-", "+").replaceAll("_", "/")
      .padEnd(Math.ceil(payloadSegment.length / 4) * 4, "=");
    issuedAt = Number(JSON.parse(atob(normalized)).iat);
  } catch {
    // getUser above validates the token; malformed timestamp data is still
    // rejected because deletion requires explicit recent authentication.
  }
  if (!Number.isFinite(issuedAt) || Date.now() / 1000 - issuedAt > 600) {
    return json({ error: "Recent authentication required" }, 403, origin);
  }

  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  // Database rows use ON DELETE CASCADE from auth-owned profiles. Delete private
  // media first because Storage objects are not covered by database cascades.
  const { data: assets, error: assetError } = await admin.from("lift_media_assets")
    .select("storage_path")
    .eq("owner_id", user.id);
  if (assetError) return json({ error: "Media cleanup lookup failed" }, 500, origin);

  const { data: submissions, error: submissionError } = await admin.from("lift_submissions")
    .select("evidence_storage_path,pending_evidence_storage_path,approved_evidence_storage_path")
    .eq("user_id", user.id);
  if (submissionError) return json({ error: "Evidence cleanup lookup failed" }, 500, origin);

  const storagePaths = new Map<string, Set<string>>();
  const addStoragePaths = (bucket: string, paths: string[]) => {
    const existing = storagePaths.get(bucket) ?? new Set<string>();
    paths.filter((path) => path.length > 0).forEach((path) => existing.add(path));
    if (existing.size) storagePaths.set(bucket, existing);
  };
  addStoragePaths("lift-videos", (assets ?? []).map((asset) => asset.storage_path));

  const legacyEvidencePaths = [...new Set((submissions ?? []).flatMap((submission) => [
    submission.evidence_storage_path,
    submission.pending_evidence_storage_path,
    submission.approved_evidence_storage_path,
  ].filter((path): path is string => typeof path === "string" && path.length > 0)))];
  if (legacyEvidencePaths.length) {
    const { data: buckets, error: bucketError } = await admin.storage.listBuckets();
    if (bucketError) return json({ error: "Evidence storage lookup failed" }, 500, origin);
    for (const bucket of (buckets ?? []).filter((candidate) => candidate.id.startsWith("lift-evidence"))) {
      addStoragePaths(bucket.id, legacyEvidencePaths);
    }
  }

  for (const [bucket, paths] of storagePaths) {
    const { error: storageError } = await admin.storage.from(bucket).remove([...paths]);
    if (storageError) return json({ error: "Media cleanup failed" }, 500, origin);
  }

  const { data: profile, error: profileError } = await admin.from("profiles").select("avatar_path").eq("id", user.id).maybeSingle();
  if (profileError) return json({ error: "Profile cleanup lookup failed" }, 500, origin);
  if (profile?.avatar_path) {
    const { error: avatarError } = await admin.storage.from("profile-avatars").remove([
      `${profile.avatar_path}/avatar-full.jpg`,
      `${profile.avatar_path}/avatar-thumb.jpg`,
    ]);
    if (avatarError) return json({ error: "Avatar cleanup failed" }, 500, origin);
  }
  const { error: deletionError } = await admin.auth.admin.deleteUser(user.id, false);
  if (deletionError) return json({ error: "Deletion failed" }, 500, origin);
  return new Response(null, { status: 204, headers: headersFor(origin) });
});
