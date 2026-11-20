-- TikTok & Reels initial additive foundation schema.
-- This migration intentionally installs no permissive client policies: until reviewed RLS policies/API authorization are added, access remains denied by default.
-- No gift prices, exchange rates, payout provider, or commission basis are inferred here.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  display_name text not null default '',
  bio text not null default '',
  avatar_asset_id uuid,
  cover_asset_id uuid,
  locale text not null default 'bn',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_length check (char_length(username) between 3 and 30),
  constraint profiles_username_format check (username ~ '^[A-Za-z0-9_]+$')
);
create unique index if not exists profiles_username_lower_uq on public.profiles (lower(username));

create table if not exists public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user','moderator','admin','owner')),
  granted_by uuid references auth.users(id),
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  purpose text not null check (purpose in ('video','thumbnail','avatar','cover','comment_voice','comment_video','gift_artwork','other')),
  provider text not null,
  object_key text not null,
  content_type text not null,
  byte_size bigint not null check (byte_size > 0),
  duration_ms bigint check (duration_ms is null or duration_ms >= 0),
  checksum_sha256 text,
  status text not null default 'pending' check (status in ('pending','validated','processing','ready','rejected','deleted')),
  created_at timestamptz not null default now(),
  unique (provider, object_key)
);

alter table public.profiles add constraint profiles_avatar_asset_fk foreign key (avatar_asset_id) references public.media_assets(id) on delete set null;
alter table public.profiles add constraint profiles_cover_asset_fk foreign key (cover_asset_id) references public.media_assets(id) on delete set null;

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references auth.users(id) on delete restrict,
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  caption text not null default '',
  description text not null default '',
  visibility text not null default 'public' check (visibility in ('public','followers','friends','private')),
  status text not null default 'draft' check (status in ('draft','processing','published','rejected','removed')),
  sound_label text,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists videos_feed_idx on public.videos (status, visibility, published_at desc) where status = 'published';

create table if not exists public.video_hashtags (
  video_id uuid not null references public.videos(id) on delete cascade,
  hashtag text not null check (char_length(hashtag) between 1 and 100),
  primary key (video_id, hashtag)
);

create table if not exists public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled','blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> addressee_id),
  unique (requester_id, addressee_id)
);

create table if not exists public.video_likes (
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

create table if not exists public.video_saves (
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

create table if not exists public.video_reposts (
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete restrict,
  parent_comment_id uuid references public.comments(id) on delete cascade,
  body text not null,
  voice_asset_id uuid references public.media_assets(id) on delete set null,
  video_asset_id uuid references public.media_assets(id) on delete set null,
  status text not null default 'visible' check (status in ('visible','reported','hidden','removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint comments_body_length check (char_length(body) between 1 and 5000)
);
create index if not exists comments_video_created_idx on public.comments (video_id, created_at desc) where deleted_at is null;

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete restrict,
  target_type text not null check (target_type in ('user','video','comment','message','live_session','channel')),
  target_id uuid not null,
  reason_code text not null,
  details text not null default '',
  status text not null default 'open' check (status in ('open','reviewing','actioned','dismissed')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  name text not null check (char_length(name) between 1 and 120),
  description text not null default '',
  visibility text not null default 'private' check (visibility in ('public','private')),
  created_at timestamptz not null default now()
);
create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('member','moderator','admin')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete restrict,
  name text not null check (char_length(name) between 1 and 120),
  description text not null default '',
  visibility text not null default 'public' check (visibility in ('public','private')),
  created_at timestamptz not null default now()
);
create table if not exists public.channel_members (
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('member','moderator','admin')),
  joined_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null default 'direct' check (kind in ('direct','group','channel')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);
create table if not exists public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('member','moderator','admin')),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (conversation_id, user_id)
);
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete restrict,
  body text not null,
  status text not null default 'sent' check (status in ('sent','reported','hidden','removed')),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  constraint messages_body_length check (char_length(body) between 1 and 10000)
);
create index if not exists messages_conversation_created_idx on public.messages (conversation_id, created_at desc);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  kind text not null,
  subject_id uuid,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.live_sessions (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references auth.users(id) on delete restrict,
  title text not null default '',
  status text not null default 'scheduled' check (status in ('scheduled','live','ended','moderated','cancelled')),
  provider text,
  provider_session_key text,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.gift_catalog (
  id uuid primary key default gen_random_uuid(),
  name_bn text not null check (char_length(name_bn) between 1 and 100),
  description_bn text not null default '',
  artwork_asset_id uuid references public.media_assets(id) on delete set null,
  price_amount numeric(20,4) not null check (price_amount > 0),
  currency text not null check (currency in ('BDT','USD')),
  is_active boolean not null default false,
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.wallet_accounts (
  id uuid primary key default gen_random_uuid(),
  wallet_class text not null check (wallet_class in ('user','admin_personal','public','commission')),
  owner_user_id uuid references auth.users(id) on delete restrict,
  currency text not null check (currency in ('BDT','USD')),
  created_at timestamptz not null default now(),
  constraint wallet_owner_class_check check (
    (wallet_class = 'user' and owner_user_id is not null) or
    (wallet_class = 'admin_personal' and owner_user_id is not null) or
    (wallet_class in ('public','commission') and owner_user_id is null)
  )
);
create unique index if not exists wallet_user_currency_uq on public.wallet_accounts(owner_user_id,currency) where wallet_class='user';
create unique index if not exists wallet_admin_personal_currency_uq on public.wallet_accounts(owner_user_id,currency) where wallet_class='admin_personal';
create unique index if not exists wallet_public_currency_uq on public.wallet_accounts(currency) where wallet_class='public';
create unique index if not exists wallet_commission_currency_uq on public.wallet_accounts(currency) where wallet_class='commission';

create table if not exists public.financial_transactions (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  transaction_type text not null check (transaction_type in ('gift','withdrawal','commission','deposit','adjustment','refund')),
  status text not null default 'pending' check (status in ('pending','approved','provider_confirmed','rejected','cancelled','reversed')),
  currency text not null check (currency in ('BDT','USD')),
  gross_amount numeric(20,4) not null check (gross_amount > 0),
  commission_amount numeric(20,4) not null default 0 check (commission_amount >= 0),
  provider_reference text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint commission_not_greater_than_gross check (commission_amount <= gross_amount),
  constraint confirmation_state_check check ((status <> 'provider_confirmed') or confirmed_at is not null)
);

create table if not exists public.ledger_entries (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.financial_transactions(id) on delete restrict,
  wallet_account_id uuid not null references public.wallet_accounts(id) on delete restrict,
  entry_kind text not null check (entry_kind in ('debit','credit')),
  amount numeric(20,4) not null check (amount > 0),
  currency text not null check (currency in ('BDT','USD')),
  created_at timestamptz not null default now(),
  unique (transaction_id, wallet_account_id, entry_kind)
);

create table if not exists public.gift_transactions (
  id uuid primary key default gen_random_uuid(),
  financial_transaction_id uuid not null unique references public.financial_transactions(id) on delete restrict,
  gift_id uuid not null references public.gift_catalog(id) on delete restrict,
  sender_id uuid not null references auth.users(id) on delete restrict,
  recipient_id uuid not null references auth.users(id) on delete restrict,
  live_session_id uuid references public.live_sessions(id) on delete set null,
  video_id uuid references public.videos(id) on delete set null,
  gift_name_bn_snapshot text not null,
  unit_price numeric(20,4) not null check (unit_price > 0),
  currency text not null check (currency in ('BDT','USD')),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  financial_transaction_id uuid not null unique references public.financial_transactions(id) on delete restrict,
  requester_id uuid not null references auth.users(id) on delete restrict,
  gross_amount numeric(20,4) not null check (gross_amount > 0),
  commission_rate_percent numeric(7,4) not null check (commission_rate_percent between 0 and 100),
  commission_amount numeric(20,4) not null check (commission_amount >= 0),
  currency text not null check (currency in ('BDT','USD')),
  status text not null default 'requested' check (status in ('requested','under_review','approved','rejected','provider_confirmed','cancelled')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  provider_reference text,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz,
  constraint withdrawal_commission_gross_check check (commission_amount <= gross_amount),
  constraint withdrawal_confirmation_check check ((status <> 'provider_confirmed') or (provider_reference is not null and confirmed_at is not null))
);

create table if not exists public.commission_settings (
  id boolean primary key default true check (id),
  gift_rate_percent numeric(7,4) not null default 5 check (gift_rate_percent between 0 and 100),
  withdrawal_rate_percent numeric(7,4) not null default 10 check (withdrawal_rate_percent between 0 and 100),
  gift_basis text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
insert into public.commission_settings (id, gift_rate_percent, withdrawal_rate_percent, gift_basis)
values (true, 5, 10, null) on conflict (id) do nothing;

create table if not exists public.fx_rate_approvals (
  id uuid primary key default gen_random_uuid(),
  from_currency text not null check (from_currency in ('BDT','USD')),
  to_currency text not null check (to_currency in ('BDT','USD')),
  rate numeric(24,10) not null check (rate > 0),
  source text not null,
  effective_at timestamptz not null,
  approved_by uuid not null references auth.users(id),
  approved_at timestamptz not null default now(),
  check (from_currency <> to_currency)
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  object_type text not null,
  object_id uuid,
  request_id text,
  before_state jsonb,
  after_state jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_events_object_idx on public.audit_events (object_type, object_id, created_at desc);

-- Closed by default: policies and narrowly scoped grants must be reviewed in a later migration.
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','user_roles','media_assets','videos','video_hashtags','follows','friend_requests',
    'video_likes','video_saves','video_reposts','comments','reports','groups','group_members',
    'channels','channel_members','conversations','conversation_participants','messages','notifications',
    'live_sessions','gift_catalog','wallet_accounts','financial_transactions','ledger_entries',
    'gift_transactions','withdrawal_requests','commission_settings','fx_rate_approvals','audit_events'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated', t);
  end loop;
end $$;
