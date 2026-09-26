create extension if not exists pgcrypto;
create type public.activity_category as enum ('play','perform','learn','create','hang_out');
create type public.activity_status as enum ('draft','published','in_progress','completed','cancelled');
create type public.join_request_status as enum ('pending','approved','rejected','withdrawn');
create type public.membership_status as enum ('active','revoked','left');

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null check(username ~ '^[A-Za-z0-9_]{3,24}$'),
 display_name text not null check(char_length(display_name) between 1 and 60),
 bio text not null default '' check(char_length(bio)<=280),
 created_at timestamptz not null default now()
);
create table public.activities (
 id uuid primary key default gen_random_uuid(),
 host_id uuid not null references public.profiles(id) on delete restrict,
 title text not null check(char_length(title) between 4 and 90),
 description text not null check(char_length(description) between 10 and 1500),
 category public.activity_category not null,
 starts_at timestamptz not null,
 duration_minutes int not null check(duration_minutes between 10 and 360),
 capacity int not null default 8 check(capacity between 2 and 100),
 status public.activity_status not null default 'draft',
 created_at timestamptz not null default now()
);
create index activities_public_discovery on public.activities(status,starts_at,category);
create table public.join_requests (
 id uuid primary key default gen_random_uuid(),
 activity_id uuid not null references public.activities(id) on delete cascade,
 requester_id uuid not null references public.profiles(id) on delete cascade,
 message text not null default '' check(char_length(message)<=500),
 status public.join_request_status not null default 'pending',
 created_at timestamptz not null default now(),
 reviewed_at timestamptz,
 unique(activity_id,requester_id)
);
create table public.memberships (
 id uuid primary key default gen_random_uuid(),
 activity_id uuid not null references public.activities(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 status public.membership_status not null default 'active',
 joined_at timestamptz not null default now(),
 revoked_at timestamptz,
 unique(activity_id,user_id)
);
create table public.room_sessions (
 id uuid primary key default gen_random_uuid(),
 activity_id uuid not null references public.activities(id) on delete cascade,
 started_at timestamptz not null default now(),
 ended_at timestamptz,
 provider_room_id text unique,
 check(ended_at is null or ended_at>=started_at)
);
create unique index one_open_room_per_activity on public.room_sessions(activity_id) where ended_at is null;
create table public.chat_messages (
 id uuid primary key default gen_random_uuid(),
 room_session_id uuid not null references public.room_sessions(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete restrict,
 body text not null check(char_length(body) between 1 and 2000),
 created_at timestamptz not null default now(),
 deleted_at timestamptz
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 kind text not null,
 activity_id uuid references public.activities(id) on delete cascade,
 read_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.user_blocks (
 blocker_id uuid not null references public.profiles(id) on delete cascade,
 blocked_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(blocker_id,blocked_id),
 check(blocker_id<>blocked_id)
);
create table public.reports (
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid not null references public.profiles(id) on delete restrict,
 reported_user_id uuid references public.profiles(id) on delete set null,
 activity_id uuid references public.activities(id) on delete set null,
 reason text not null check(char_length(reason) between 10 and 2000),
 status text not null default 'open' check(status in ('open','reviewing','resolved','dismissed')),
 created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.activities enable row level security;
alter table public.join_requests enable row level security;
alter table public.memberships enable row level security;
alter table public.room_sessions enable row level security;
alter table public.chat_messages enable row level security;
alter table public.notifications enable row level security;
alter table public.user_blocks enable row level security;
alter table public.reports enable row level security;

create policy "Authenticated users can view profiles" on public.profiles for select to authenticated using(true);
create policy "Users create own profile" on public.profiles for insert to authenticated with check(auth.uid()=id);
create policy "Users update own profile" on public.profiles for update to authenticated using(auth.uid()=id) with check(auth.uid()=id);
create policy "Discover published activities" on public.activities for select to authenticated using(status='published' and starts_at>now() or host_id=auth.uid() or exists(select 1 from public.memberships m where m.activity_id=id and m.user_id=auth.uid() and m.status='active'));
create policy "Hosts create activities" on public.activities for insert to authenticated with check(host_id=auth.uid());
create policy "Hosts update own activities" on public.activities for update to authenticated using(host_id=auth.uid()) with check(host_id=auth.uid());
create policy "Requester or host reads requests" on public.join_requests for select to authenticated using(requester_id=auth.uid() or exists(select 1 from public.activities a where a.id=activity_id and a.host_id=auth.uid()));
create policy "Users submit own pending requests" on public.join_requests for insert to authenticated with check(requester_id=auth.uid() and status='pending');
create policy "Requesters withdraw own pending requests" on public.join_requests for update to authenticated using(requester_id=auth.uid() and status='pending') with check(requester_id=auth.uid() and status='withdrawn');
create policy "Users read own memberships" on public.memberships for select to authenticated using(user_id=auth.uid() or exists(select 1 from public.activities a where a.id=activity_id and a.host_id=auth.uid()));
create policy "Active members read room sessions" on public.room_sessions for select to authenticated using(exists(select 1 from public.memberships m where m.activity_id=activity_id and m.user_id=auth.uid() and m.status='active'));
create policy "Room members read chat" on public.chat_messages for select to authenticated using(exists(select 1 from public.room_sessions s join public.memberships m on m.activity_id=s.activity_id where s.id=room_session_id and m.user_id=auth.uid() and m.status='active'));
create policy "Active room members send chat" on public.chat_messages for insert to authenticated with check(sender_id=auth.uid() and exists(select 1 from public.room_sessions s join public.memberships m on m.activity_id=s.activity_id where s.id=room_session_id and m.user_id=auth.uid() and m.status='active' and s.ended_at is null));
create policy "Read own notifications" on public.notifications for select to authenticated using(recipient_id=auth.uid());
create policy "Read own blocks" on public.user_blocks for select to authenticated using(blocker_id=auth.uid());
create policy "Insert own blocks" on public.user_blocks for insert to authenticated with check(blocker_id=auth.uid());
create policy "Delete own blocks" on public.user_blocks for delete to authenticated using(blocker_id=auth.uid());
create policy "Submit own reports" on public.reports for insert to authenticated with check(reporter_id=auth.uid());
create policy "Read own reports" on public.reports for select to authenticated using(reporter_id=auth.uid());

-- Deliberately no client writes to memberships or room sessions. A trusted server
-- function must approve requests, provision rooms, issue credentials, and revoke access.
