import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

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

  const { data: reserved, error: reserveError } = await admin.rpc("reserve_lift_removal", {
    target_lift_id: submissionID,
    target_owner_id: user.id,
  });
  if (reserveError) return json({ error: reserveError.code === "P0002" ? "Submission not found or no longer available" : "Removal could not be reserved; contact support if this persists" }, reserveError.code === "P0002" ? 404 : 409);
  if (!reserved || !isUuid(reserved.id) || !Array.isArray(reserved.storage_objects)) return json({ error: "Removal reservation could not be read" }, 500);
  const requestID = reserved.id;
  const protectedRecord = reserved.protected_record === true;
  if (reserved.status === "completed") return json({ status: "completed", protected_record: protectedRecord });
  const storageObjects: StorageObject[] = reserved.storage_objects;
  if (reserved.status !== "processing" || storageObjects.some((object) =>
    typeof object?.name !== "string" || !object.name.startsWith(`${user.id}/${submissionID}/`) ||
    /(^|\/)\.\.?(\/|$)/.test(object.name) ||
    typeof object.bucket_id !== "string" || (object.bucket_id !== "lift-videos" && !object.bucket_id.startsWith("lift-evidence"))
  )) return json({ error: "Evidence paths require administrative repair" }, 409);

  for (const bucket of new Set(storageObjects.map((object) => object.bucket_id))) {
    const paths = storageObjects.filter((object) => object.bucket_id === bucket).map((object) => object.name);
    for (let offset = 0; offset < paths.length; offset += 100) {
      const { error } = await admin.storage.from(bucket).remove(paths.slice(offset, offset + 100));
      if (error) {
        await admin.from("lift_removal_requests").update({ status: "failed", last_error: `storage_cleanup_failed:${bucket}` }).eq("id", requestID).neq("status", "completed");
        return json({ error: "Evidence cleanup did not finish; the removal can be retried safely" }, 500);
      }
    }
  }

  const { error: finalizeError } = await admin.rpc("finalize_lift_removal", { target_request_id: requestID });
  if (finalizeError) {
    await admin.from("lift_removal_requests").update({ status: "failed", last_error: "database_finalize_failed" }).eq("id", requestID).neq("status", "completed");
    return json({ error: "Database cleanup did not finish; the removal can be retried safely" }, 500);
  }

  return json({ status: "completed", protected_record: protectedRecord });
});
