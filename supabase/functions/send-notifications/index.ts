import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5.9.6";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";
import { isTransientPushFailure, shouldMarkApnsDeliveryComplete } from "../_shared/notification-delivery.js";

type NotificationRow = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  kind: string;
  destination: Record<string, unknown>;
  push_sent_at: string | null;
  web_push_sent_at: string | null;
};

type WebPushSubscriptionRow = { endpoint: string; subscription: { endpoint: string; keys: { auth: string; p256dh: string } } };

function isSupportedWebPushEndpoint(value: unknown): value is string {
  if (typeof value !== "string") return false;
  try {
    const endpoint = new URL(value);
    return endpoint.protocol === "https:"
      && ["fcm.googleapis.com", "updates.push.services.mozilla.com", "push.services.mozilla.com", "web.push.apple.com"].includes(endpoint.hostname)
      && !endpoint.username && !endpoint.password;
  } catch {
    return false;
  }
}

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
  const webPushPublicKey = Deno.env.get("WEB_PUSH_VAPID_PUBLIC_KEY");
  const webPushPrivateKey = Deno.env.get("WEB_PUSH_VAPID_PRIVATE_KEY");
  const webPushSubject = Deno.env.get("WEB_PUSH_VAPID_SUBJECT") ?? "mailto:support@liftrivals.com";
  const launchProfile = Deno.env.get("LIFTRANK_LAUNCH_PROFILE") ?? "focused_v1";
  const webPushConfigured = Boolean(webPushPublicKey && webPushPrivateKey);
  if (!supabaseURL || !serviceKey || !teamID || !keyID || !privateKey || !topic || Boolean(webPushPublicKey) !== Boolean(webPushPrivateKey)) {
    return new Response("Server configuration missing", { status: 500 });
  }

  const admin = createClient(supabaseURL, serviceKey, { auth: { persistSession: false } });
  let pendingQuery = admin.from("notifications")
    .select("id,user_id,title,body,kind,destination,push_sent_at,web_push_sent_at");
  pendingQuery = webPushConfigured
    ? pendingQuery.or("push_sent_at.is.null,web_push_sent_at.is.null")
    : pendingQuery.is("push_sent_at", null);
  const { data: pending, error } = await pendingQuery.order("created_at").limit(100);
  if (error) return new Response("Notification query failed", { status: 500 });

  if (webPushConfigured) {
    webpush.setVapidDetails(webPushSubject, webPushPublicKey!, webPushPrivateKey!);
  }

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
      const deferredAt = new Date().toISOString();
      await admin.from("notifications").update({
        ...(notification.push_sent_at ? {} : { push_sent_at: deferredAt }),
        ...(webPushConfigured && !notification.web_push_sent_at ? { web_push_sent_at: deferredAt } : {}),
      }).eq("id", notification.id);
      continue;
    }
    const notificationUpdate: Record<string, string> = {};
    if (!notification.push_sent_at) {
      const { data: devices, error: devicesError } = await admin.from("device_tokens")
        .select("id,token,environment")
        .eq("user_id", notification.user_id)
        .is("revoked_at", null);
      if (devicesError) return new Response("Device query failed", { status: 500 });
      let notificationDelivered = false;
      let transientFailure = false;
      for (const device of devices ?? []) {
        const host = device.environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
        let response: Response;
        try {
          response = await fetch(`https://${host}/3/device/${device.token}`, {
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
        } catch {
          transientFailure = true;
          continue;
        }
        if (response.ok) {
          notificationDelivered = true;
          delivered += 1;
        } else if (response.status === 410) {
          await admin.from("device_tokens").update({ revoked_at: new Date().toISOString() }).eq("id", device.id);
        } else if (isTransientPushFailure(response.status)) {
          transientFailure = true;
        }
      }
      // A channel is complete when delivered or when no retryable target remains.
      // This also closes notifications with no active device, avoiding a stuck oldest batch.
      if (shouldMarkApnsDeliveryComplete(notificationDelivered, transientFailure)) {
        notificationUpdate.push_sent_at = new Date().toISOString();
      }
    }

    if (notificationUpdate.push_sent_at) {
      const { error: apnsUpdateError } = await admin.from("notifications")
        .update({ push_sent_at: notificationUpdate.push_sent_at })
        .eq("id", notification.id);
      if (apnsUpdateError) return new Response("APNs delivery state update failed", { status: 500 });
      delete notificationUpdate.push_sent_at;
    }

    if (webPushConfigured && !notification.web_push_sent_at) {
      const { data: subscriptions, error: subscriptionsError } = await admin.from("web_push_subscriptions")
        .select("endpoint,subscription")
        .eq("user_id", notification.user_id)
        .is("revoked_at", null);
      if (subscriptionsError) return new Response("Web push subscription query failed", { status: 500 });
      let transientFailure = false;
      for (const row of (subscriptions ?? []) as WebPushSubscriptionRow[]) {
        if (!isSupportedWebPushEndpoint(row.subscription?.endpoint)) {
          await admin.from("web_push_subscriptions").update({ revoked_at: new Date().toISOString() }).eq("endpoint", row.endpoint);
          continue;
        }
        try {
          await webpush.sendNotification(row.subscription, JSON.stringify({
            id: notification.id,
            title: notification.title,
            body: notification.body,
            destination: notification.destination,
          }));
          delivered += 1;
        } catch (pushError) {
          const statusCode = Number((pushError as { statusCode?: unknown })?.statusCode || 0);
          if (statusCode === 404 || statusCode === 410) {
            await admin.from("web_push_subscriptions").update({ revoked_at: new Date().toISOString() }).eq("endpoint", row.endpoint);
          } else if (isTransientPushFailure(statusCode)) {
            transientFailure = true;
          } else {
            await admin.from("web_push_subscriptions").update({ revoked_at: new Date().toISOString() }).eq("endpoint", row.endpoint);
          }
        }
      }
      if (!transientFailure) {
        notificationUpdate.web_push_sent_at = new Date().toISOString();
      }
    }
    if (Object.keys(notificationUpdate).length) {
      const { error: updateError } = await admin.from("notifications").update(notificationUpdate).eq("id", notification.id);
      if (updateError) return new Response("Notification delivery state update failed", { status: 500 });
    }
  }

  return Response.json({ notifications: pending?.length ?? 0, delivered });
});
