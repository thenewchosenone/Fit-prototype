import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const authorization = request.headers.get("Authorization") ?? "";
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return new Response("Server configuration missing", { status: 500 });

  const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return new Response("Unauthorized", { status: 401 });

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
    return new Response("Recent authentication required", { status: 403 });
  }

  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  // Database rows use ON DELETE CASCADE from auth-owned profiles. Delete private
  // media first because Storage objects are not covered by database cascades.
  const { data: assets } = await admin.from("lift_media_assets").select("storage_path").eq("owner_id", user.id);
  if (assets?.length) await admin.storage.from("lift-videos").remove(assets.map((asset) => asset.storage_path));
  const { error: deletionError } = await admin.auth.admin.deleteUser(user.id, false);
  if (deletionError) return new Response("Deletion failed", { status: 500 });
  return new Response(null, { status: 204 });
});
