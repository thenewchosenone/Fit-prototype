create index if not exists forum_comments_post_created_id_visible_idx
  on public.forum_comments (post_id, created_at, id)
  where removed_at is null;
