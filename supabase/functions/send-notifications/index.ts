import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type NotificationRow = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  kind: string;
  destination: Record<string, unknown>;
};

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const internalSecret = Deno.env.get("NOTIFICATION_DELIVERY_SECRET");
  if (!internalSecret || request.headers.get("Authorization") !== `Bearer ${internalSecret}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  const keyID = Deno.env.get("APNS_KEY_ID");
  const privateKey = Deno.env.get("APNS_PRIVATE_KEY")?.replaceAll("\\n", "\n");
  const topic = Deno.env.get("APNS_BUNDLE_ID");
  const launchProfile = Deno.env.get("LIFTRANK_LAUNCH_PROFILE") ?? "focused_v1";
  if (!supabaseURL || !serviceKey || !teamID || !keyID || !privateKey || !topic) {
    return new Response("Server configuration missing", { status: 500 });
  }

  const admin = createClient(supabaseURL, serviceKey, { auth: { persistSession: false } });
  const { data: pending, error } = await admin.from("notifications")
    .select("id,user_id,title,body,kind,destination")
    .is("push_sent_at", null)
    .order("created_at")
    .limit(100);
  if (error) return new Response("Notification query failed", { status: 500 });

  const signingKey = await importPKCS8(privateKey, "ES256");
  const providerToken = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyID })
    .setIssuer(teamID)
    .setIssuedAt()
    .sign(signingKey);
  let delivered = 0;

  for (const notification of (pending ?? []) as NotificationRow[]) {
    const deferredKinds = new Set(["message", "forum_reply", "community"]);
    if (launchProfile === "focused_v1" && deferredKinds.has(notification.kind)) {
      await admin.from("notifications").update({ push_sent_at: new Date().toISOString() }).eq("id", notification.id);
      continue;
    }
    const { data: devices } = await admin.from("device_tokens")
      .select("id,token,environment")
      .eq("user_id", notification.user_id)
      .is("revoked_at", null);
    let notificationDelivered = false;
    for (const device of devices ?? []) {
      const host = device.environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
      const response = await fetch(`https://${host}/3/device/${device.token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${providerToken}`,
          "apns-topic": topic,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          aps: { alert: { title: notification.title, body: notification.body }, sound: "default" },
          destination: notification.destination,
        }),
      });
      if (response.ok) {
        notificationDelivered = true;
        delivered += 1;
      } else if (response.status === 410) {
        await admin.from("device_tokens").update({ revoked_at: new Date().toISOString() }).eq("id", device.id);
      }
    }
    if (notificationDelivered) {
      await admin.from("notifications").update({ push_sent_at: new Date().toISOString() }).eq("id", notification.id);
    }
  }

  return Response.json({ notifications: pending?.length ?? 0, delivered });
});
