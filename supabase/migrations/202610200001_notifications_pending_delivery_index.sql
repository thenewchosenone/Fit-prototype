create index notifications_pending_delivery_created_at_idx
  on public.notifications (created_at)
  where push_sent_at is null or web_push_sent_at is null;
