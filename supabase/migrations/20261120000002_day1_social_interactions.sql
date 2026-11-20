-- Day-1 Social Interaction RPC foundation.
-- Depends on 20261120000000_phase1_foundation.sql. This migration adds no access
-- to private/follower/friend videos: all interactions here require published public videos.
-- Direct client writes to likes, comments, reports and comment_likes remain revoked.

create table public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);
alter table public.comment_likes enable row level security;
revoke all on table public.comment_likes from anon, authenticated;

create function public.day1_is_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles r
    where r.user_id = auth.uid()
      and r.role in ('moderator', 'admin', 'owner')
  );
$$;
revoke all on function public.day1_is_moderator() from public, anon, authenticated;
-- RLS expressions call this helper; authenticated callers require EXECUTE.
grant execute on function public.day1_is_moderator() to authenticated;

create function public.day1_require_public_video(p_video_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.videos v
    where v.id = p_video_id
      and v.status = 'published'
      and v.visibility = 'public'
  ) then
    raise exception 'video is not available for public interaction' using errcode = '42501';
  end if;
end;
$$;
revoke all on function public.day1_require_public_video(uuid) from public, anon, authenticated;

-- Read-only public feed and visible comments. Private content remains owner-only.
grant select on public.videos, public.comments, public.reports to authenticated;
create policy day1_videos_read_public_or_own
on public.videos for select to authenticated
using (creator_id = auth.uid() or (status = 'published' and visibility = 'public'));

create policy day1_comments_read_visible_or_author_or_moderator
on public.comments for select to authenticated
using (
  (status = 'visible' and deleted_at is null and exists (
    select 1 from public.videos v
    where v.id = video_id and v.status = 'published' and v.visibility = 'public'
  ))
  or author_id = auth.uid()
  or public.day1_is_moderator()
);

create policy day1_reports_read_reporter_or_moderator
on public.reports for select to authenticated
using (reporter_id = auth.uid() or public.day1_is_moderator());

create function public.like_video(p_video_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare affected integer;
begin
  perform public.day1_require_public_video(p_video_id);
  insert into public.video_likes(video_id, user_id)
  values (p_video_id, auth.uid())
  on conflict (video_id, user_id) do nothing;
  get diagnostics affected = row_count;
  return affected = 1;
end;
$$;

create function public.unlike_video(p_video_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare affected integer;
begin
  perform public.day1_require_public_video(p_video_id);
  delete from public.video_likes
  where video_id = p_video_id and user_id = auth.uid();
  get diagnostics affected = row_count;
  return affected = 1;
end;
$$;

create function public.video_like_count(p_video_id uuid)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare result_count bigint;
begin
  perform public.day1_require_public_video(p_video_id);
  select count(*) into result_count
  from public.video_likes l where l.video_id = p_video_id;
  return result_count;
end;
$$;

create function public.video_likers(
  p_video_id uuid, p_limit integer default 50, p_offset integer default 0
)
returns table(liker_id uuid, liked_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.day1_require_public_video(p_video_id);
  return query
    select l.user_id, l.created_at
    from public.video_likes l
    where l.video_id = p_video_id
    order by l.created_at desc, l.user_id
    limit least(greatest(coalesce(p_limit, 50), 1), 100)
    offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create function public.create_comment(
  p_video_id uuid,
  p_body text,
  p_parent_comment_id uuid default null,
  p_voice_asset_id uuid default null,
  p_video_asset_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare created_id uuid;
begin
  perform public.day1_require_public_video(p_video_id);
  if p_body is null or char_length(btrim(p_body)) not between 1 and 5000 then
    raise exception 'comment body must contain 1 to 5000 characters';
  end if;
  if p_parent_comment_id is not null and not exists (
    select 1 from public.comments c
    where c.id = p_parent_comment_id
      and c.video_id = p_video_id
      and c.status = 'visible'
      and c.deleted_at is null
  ) then
    raise exception 'reply parent is not visible on this video';
  end if;
  if p_voice_asset_id is not null and not exists (
    select 1 from public.media_assets a
    where a.id = p_voice_asset_id
      and a.owner_id = auth.uid()
      and a.purpose = 'comment_voice'
      and a.status = 'ready'
  ) then
    raise exception 'voice attachment is not an owned, ready comment asset' using errcode = '42501';
  end if;
  if p_video_asset_id is not null and not exists (
    select 1 from public.media_assets a
    where a.id = p_video_asset_id
      and a.owner_id = auth.uid()
      and a.purpose = 'comment_video'
      and a.status = 'ready'
  ) then
    raise exception 'video attachment is not an owned, ready comment asset' using errcode = '42501';
  end if;
  insert into public.comments(video_id, author_id, parent_comment_id, body, voice_asset_id, video_asset_id)
  values (p_video_id, auth.uid(), p_parent_comment_id, btrim(p_body), p_voice_asset_id, p_video_asset_id)
  returning id into created_id;
  return created_id;
end;
$$;

create function public.edit_comment(p_comment_id uuid, p_body text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare affected integer;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if p_body is null or char_length(btrim(p_body)) not between 1 and 5000 then
    raise exception 'comment body must contain 1 to 5000 characters';
  end if;
  update public.comments
  set body = btrim(p_body), edited_at = now(), updated_at = now()
  where id = p_comment_id and author_id = auth.uid()
    and status = 'visible' and deleted_at is null;
  get diagnostics affected = row_count;
  return affected = 1;
end;
$$;

create function public.delete_comment(p_comment_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare affected integer;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  update public.comments
  set deleted_at = now(), updated_at = now()
  where id = p_comment_id and author_id = auth.uid() and deleted_at is null;
  get diagnostics affected = row_count;
  return affected = 1;
end;
$$;

create function public.like_comment(p_comment_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare affected integer;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if not exists (
    select 1 from public.comments c join public.videos v on v.id = c.video_id
    where c.id = p_comment_id and c.status = 'visible' and c.deleted_at is null
      and v.status = 'published' and v.visibility = 'public'
  ) then raise exception 'comment is not available for public interaction' using errcode = '42501'; end if;
  insert into public.comment_likes(comment_id, user_id)
  values (p_comment_id, auth.uid()) on conflict (comment_id, user_id) do nothing;
  get diagnostics affected = row_count;
  return affected = 1;
end;
$$;

create function public.unlike_comment(p_comment_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare affected integer;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  delete from public.comment_likes
  where comment_id = p_comment_id and user_id = auth.uid();
  get diagnostics affected = row_count;
  return affected = 1;
end;
$$;

create function public.comment_like_count(p_comment_id uuid)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare result_count bigint;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if not exists (
    select 1 from public.comments c join public.videos v on v.id = c.video_id
    where c.id = p_comment_id and c.status = 'visible' and c.deleted_at is null
      and v.status = 'published' and v.visibility = 'public'
  ) then raise exception 'comment is not available' using errcode = '42501'; end if;
  select count(*) into result_count from public.comment_likes l where l.comment_id = p_comment_id;
  return result_count;
end;
$$;

create function public.create_report(
  p_target_type text, p_target_id uuid, p_reason_code text, p_details text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare created_id uuid; target_exists boolean := false;
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if p_reason_code is null or char_length(btrim(p_reason_code)) not between 1 and 100
     or coalesce(char_length(p_details), 0) > 2000 then
    raise exception 'invalid report details';
  end if;
  case p_target_type
    when 'user' then select exists(select 1 from auth.users u where u.id = p_target_id) into target_exists;
    when 'video' then select exists(select 1 from public.videos v where v.id = p_target_id) into target_exists;
    when 'comment' then select exists(select 1 from public.comments c where c.id = p_target_id) into target_exists;
    when 'message' then select exists(select 1 from public.messages m where m.id = p_target_id) into target_exists;
    when 'live_session' then select exists(select 1 from public.live_sessions l where l.id = p_target_id) into target_exists;
    when 'channel' then select exists(select 1 from public.channels c where c.id = p_target_id) into target_exists;
    else raise exception 'report target is unavailable';
  end case;
  if not target_exists then raise exception 'report target is unavailable'; end if;
  insert into public.reports(reporter_id, target_type, target_id, reason_code, details, status, reviewed_by, reviewed_at)
  values(auth.uid(), p_target_type, p_target_id, btrim(p_reason_code), coalesce(p_details, ''), 'open', null, null)
  returning id into created_id;
  return created_id;
end;
$$;

create function public.review_report(p_report_id uuid, p_status text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare previous_status text;
begin
  if auth.uid() is null or not public.day1_is_moderator() then
    raise exception 'moderator permission required' using errcode = '42501';
  end if;
  if p_status not in ('reviewing', 'actioned', 'dismissed') then raise exception 'invalid report status'; end if;
  select r.status into previous_status from public.reports r where r.id = p_report_id for update;
  if not found then return false; end if;
  update public.reports set status = p_status, reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_report_id;
  insert into public.audit_events(actor_id, action, object_type, object_id, before_state, after_state)
  values(auth.uid(), 'review_report', 'report', p_report_id,
    jsonb_build_object('status', previous_status), jsonb_build_object('status', p_status));
  return true;
end;
$$;

create function public.moderate_comment(p_comment_id uuid, p_status text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare previous_status text;
begin
  if auth.uid() is null or not public.day1_is_moderator() then
    raise exception 'moderator permission required' using errcode = '42501';
  end if;
  if p_status not in ('visible', 'hidden', 'removed') then raise exception 'invalid moderation status'; end if;
  select c.status into previous_status from public.comments c
  where c.id = p_comment_id and c.deleted_at is null for update;
  if not found then return false; end if;
  update public.comments set status = p_status, updated_at = now()
  where id = p_comment_id and deleted_at is null;
  insert into public.audit_events(actor_id, action, object_type, object_id, before_state, after_state)
  values(auth.uid(), 'moderate_comment', 'comment', p_comment_id,
    jsonb_build_object('status', previous_status), jsonb_build_object('status', p_status));
  return true;
end;
$$;

revoke all on function public.like_video(uuid) from public, anon;
revoke all on function public.unlike_video(uuid) from public, anon;
revoke all on function public.video_like_count(uuid) from public, anon;
revoke all on function public.video_likers(uuid, integer, integer) from public, anon;
revoke all on function public.create_comment(uuid, text, uuid, uuid, uuid) from public, anon;
revoke all on function public.edit_comment(uuid, text) from public, anon;
revoke all on function public.delete_comment(uuid) from public, anon;
revoke all on function public.like_comment(uuid) from public, anon;
revoke all on function public.unlike_comment(uuid) from public, anon;
revoke all on function public.comment_like_count(uuid) from public, anon;
revoke all on function public.create_report(text, uuid, text, text) from public, anon;
revoke all on function public.review_report(uuid, text) from public, anon;
revoke all on function public.moderate_comment(uuid, text) from public, anon;
grant execute on function public.like_video(uuid) to authenticated;
grant execute on function public.unlike_video(uuid) to authenticated;
grant execute on function public.video_like_count(uuid) to authenticated;
grant execute on function public.video_likers(uuid, integer, integer) to authenticated;
grant execute on function public.create_comment(uuid, text, uuid, uuid, uuid) to authenticated;
grant execute on function public.edit_comment(uuid, text) to authenticated;
grant execute on function public.delete_comment(uuid) to authenticated;
grant execute on function public.like_comment(uuid) to authenticated;
grant execute on function public.unlike_comment(uuid) to authenticated;
grant execute on function public.comment_like_count(uuid) to authenticated;
grant execute on function public.create_report(text, uuid, text, text) to authenticated;
grant execute on function public.review_report(uuid, text) to authenticated;
grant execute on function public.moderate_comment(uuid, text) to authenticated;
