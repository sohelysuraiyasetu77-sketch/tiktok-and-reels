-- pgTAP structural/privilege checks for the Day-1 social migration.
-- Run only against a disposable local Supabase database after all migrations.
begin;
select plan(14);
select has_table('public', 'comment_likes', 'comment_likes table exists');
select has_function('public', 'day1_is_moderator', array[]::text[], 'moderator helper exists');
select has_function('public', 'like_video', array['uuid'], 'Like RPC exists');
select has_function('public', 'unlike_video', array['uuid'], 'Unlike RPC exists');
select has_function('public', 'create_comment', array['uuid','text','uuid','uuid','uuid'], 'Comment/reply RPC exists');
select has_function('public', 'edit_comment', array['uuid','text'], 'Edit RPC exists');
select has_function('public', 'delete_comment', array['uuid'], 'Soft-delete RPC exists');
select has_function('public', 'like_comment', array['uuid'], 'Comment Like RPC exists');
select has_function('public', 'create_report', array['text','uuid','text','text'], 'Report RPC exists');
select ok((select relrowsecurity from pg_class where oid='public.comment_likes'::regclass), 'comment likes RLS enabled');
select ok(not has_table_privilege('authenticated','public.comment_likes','INSERT'), 'direct comment-like insert denied');
select ok(not has_table_privilege('authenticated','public.comments','DELETE'), 'hard comment delete denied');
select ok(has_function_privilege('authenticated','public.day1_is_moderator()','EXECUTE'), 'RLS helper executable by authenticated role');
select ok(not has_function_privilege('anon','public.day1_is_moderator()','EXECUTE'), 'RLS helper not executable by anon');
select * from finish();
rollback;
