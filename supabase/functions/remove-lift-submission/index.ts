import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: Record<string, unknown>, status = 200) => new Response(
  JSON.stringify(body),
  { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
);

const isUuid = (value: unknown): value is string =>
  typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);

type StorageObject = { bucket_id: string; name: string };

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization") ?? "";
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "Server configuration missing" }, 500);

  let payload: { submission_id?: unknown };
  try {
    payload = await request.json();
  } catch {
    return json({ error: "A JSON request body is required" }, 400);
  }
  if (!isUuid(payload.submission_id)) return json({ error: "A valid submission_id is required" }, 400);

  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return json({ error: "Unauthorized" }, 401);

  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const submissionID = payload.submission_id;

  const { data: existingRequest } = await admin.from("lift_removal_requests")
    .select("id,status,protected_record")
    .eq("lift_id", submissionID)
    .eq("owner_id", user.id)
    .maybeSingle();
  if (existingRequest?.status === "completed") {
    return json({ status: "completed", protected_record: existingRequest.protected_record });
  }

  const { data: submission, error: submissionError } = await admin.from("lift_submissions")
    .select("*")
    .eq("id", submissionID)
    .eq("user_id", user.id)
    .maybeSingle();
  if (submissionError) return json({ error: "Submission lookup failed" }, 500);
  if (!submission) {
    return existingRequest
      ? json({ error: "Removal is incomplete; retry after the server state is repaired" }, 409)
      : json({ error: "Submission not found or no longer available" }, 404);
  }

  const { data: mediaAssets, error: mediaError } = await admin.from("lift_media_assets")
    .select("storage_path")
    .eq("lift_id", submissionID)
    .eq("owner_id", user.id);
  if (mediaError) return json({ error: "Submission media lookup failed" }, 500);

  const candidatePaths = [...new Set([
    ...(mediaAssets ?? []).map((asset) => asset.storage_path),
    submission.approved_evidence_storage_path,
    submission.pending_evidence_storage_path,
    submission.evidence_storage_path,
  ].filter((value): value is string => typeof value === "string" && value.length > 0))];

  const mediaPaths = new Set((mediaAssets ?? []).map((asset) => asset.storage_path));
  let storageObjects: StorageObject[] = candidatePaths
    .filter((path) => mediaPaths.has(path))
    .map((name) => ({ bucket_id: "lift-videos", name }));
  const legacyEvidencePaths = candidatePaths.filter((path) => !mediaPaths.has(path));
  if (legacyEvidencePaths.length) {
    const { data: buckets, error: bucketError } = await admin.storage.listBuckets();
    if (bucketError) return json({ error: "Evidence storage lookup failed" }, 500);
    const evidenceBuckets = (buckets ?? [])
      .map((bucket) => bucket.id)
      .filter((id) => id.startsWith("lift-evidence"));
    storageObjects = storageObjects.concat(
      evidenceBuckets.flatMap((bucket_id) => legacyEvidencePaths.map((name) => ({ bucket_id, name }))),
    );
  }

  const protectedRecord = Boolean(
    submission.evidence_status !== "self_reported" ||
    submission.video_asset_id ||
    candidatePaths.length ||
    submission.review_status === "approved" ||
    submission.evidence_public,
  );

  const { data: reservedRequest, error: requestError } = await admin.from("lift_removal_requests").upsert({
    lift_id: submissionID,
    owner_id: user.id,
    status: "processing",
    protected_record: protectedRecord,
    lift_snapshot: submission,
    storage_objects: storageObjects,
    last_error: null,
    updated_at: new Date().toISOString(),
  }, { onConflict: "lift_id" }).select("id").single();
  if (requestError || !reservedRequest) return json({ error: "Removal request could not be recorded" }, 500);
  const requestID = reservedRequest.id;

  for (const bucket of new Set(storageObjects.map((object) => object.bucket_id))) {
    const paths = storageObjects.filter((object) => object.bucket_id === bucket).map((object) => object.name);
    const { error } = await admin.storage.from(bucket).remove(paths);
    if (error) {
      await admin.from("lift_removal_requests").update({ status: "failed", last_error: `storage_cleanup_failed:${bucket}` }).eq("id", requestID);
      return json({ error: "Evidence cleanup did not finish; the removal can be retried safely" }, 500);
    }
  }

  const { error: finalizeError } = await admin.rpc("finalize_lift_removal", { target_request_id: requestID });
  if (finalizeError) {
    await admin.from("lift_removal_requests").update({ status: "failed", last_error: "database_finalize_failed" }).eq("id", requestID);
    return json({ error: "Database cleanup did not finish; the removal can be retried safely" }, 500);
  }

  return json({ status: "completed", protected_record: protectedRecord });
});
