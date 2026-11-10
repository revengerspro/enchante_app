# Enchanté

Enchanté is a Flutter chat app backed by Supabase Auth, Postgres, and Realtime.
Users sign in with their username, email, and password, then start private
one-to-one conversations or create separate group conversations. There is no
shared chat room or in-app sign-up. Chat messages are visible for 24 hours to
regular members; the administrator archive remains unfiltered.

## Supabase setup

Run this complete SQL script in the Supabase SQL Editor. It creates/upgrades the
profile and chat-room schema, username trigger, secure RPCs, row-level policies,
and Realtime publication for messages.

```sql
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  text text not null check (char_length(text) between 1 and 10000),
  sender_id uuid not null references auth.users (id) on delete cascade,
  sender_email text not null,
  room_id text not null,
  created_at timestamptz not null default now()
);

alter table public.messages alter column room_id drop default;

create index if not exists messages_room_created_at_idx
  on public.messages (room_id, created_at);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null check (username ~ '^[A-Za-z0-9_]{3,24}$'),
  created_at timestamptz not null default now()
);

create unique index if not exists profiles_username_ci_idx
  on public.profiles (lower(username));

insert into public.profiles (id, username)
select
  u.id,
  lower(
    left(
      regexp_replace(split_part(coalesce(u.email, ''), '@', 1),
                     '[^A-Za-z0-9_]', '', 'g'),
      16
    ) || '_' || left(replace(u.id::text, '-', ''), 6)
  )
from auth.users u
on conflict (id) do nothing;

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_username text;
begin
  requested_username := lower(coalesce(new.raw_user_meta_data ->> 'username', ''));
  if requested_username !~ '^[A-Za-z0-9_]{3,24}$' then
    requested_username := lower(
      left(
        regexp_replace(split_part(coalesce(new.email, ''), '@', 1),
                       '[^A-Za-z0-9_]', '', 'g'),
        16
      ) || '_' || left(replace(new.id::text, '-', ''), 6)
    );
  end if;
  insert into public.profiles (id, username)
  values (new.id, requested_username);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.handle_new_user_profile();

create table if not exists public.chat_rooms (
  id text primary key,
  name text not null,
  room_type text not null check (room_type in ('direct', 'group')),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.chat_room_members (
  room_id text not null references public.chat_rooms (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

delete from public.chat_room_members where room_id = 'general';

create index if not exists chat_room_members_user_idx
  on public.chat_room_members (user_id, room_id);

create or replace function public.is_chat_room_member(p_room_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_room_members m
    where m.room_id = p_room_id and m.user_id = auth.uid()
  );
$$;

create or replace function public.get_my_chat_rooms()
returns table (room_id text, room_name text, room_type text)
language sql
stable
security definer
set search_path = public
as $$
  select
    r.id,
    case
      when r.room_type = 'direct' then coalesce((
        select p.username
        from public.chat_room_members m
        join public.profiles p on p.id = m.user_id
        where m.room_id = r.id and m.user_id <> auth.uid()
        limit 1
      ), 'Direct chat')
      else r.name
    end,
    r.room_type
  from public.chat_rooms r
  where public.is_chat_room_member(r.id)
  order by r.created_at desc;
$$;

create or replace function public.start_direct_chat(other_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  direct_room_id text;
begin
  if current_user_id is null or other_user_id is null
     or current_user_id = other_user_id then
    raise exception 'Choose another registered user';
  end if;
  if not exists (select 1 from public.profiles p where p.id = other_user_id) then
    raise exception 'User profile not found';
  end if;

  direct_room_id := 'dm_' || least(current_user_id::text, other_user_id::text)
                    || '_' || greatest(current_user_id::text, other_user_id::text);
  insert into public.chat_rooms (id, name, room_type, created_by)
  values (direct_room_id, 'Direct chat', 'direct', current_user_id)
  on conflict (id) do nothing;

  insert into public.chat_room_members (room_id, user_id)
  values (direct_room_id, current_user_id), (direct_room_id, other_user_id)
  on conflict do nothing;
  return direct_room_id;
end;
$$;

create or replace function public.create_group_chat(
  p_name text,
  p_member_ids uuid[]
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  group_room_id text := gen_random_uuid()::text;
  requested_count integer := cardinality(coalesce(p_member_ids, '{}'::uuid[]));
  valid_count integer;
begin
  if current_user_id is null then
    raise exception 'Sign in to create a group';
  end if;
  if char_length(trim(coalesce(p_name, ''))) not between 1 and 60 then
    raise exception 'Group name must be between 1 and 60 characters';
  end if;
  if requested_count < 1 or requested_count > 100 then
    raise exception 'Select between 1 and 100 other members';
  end if;

  select count(distinct requested.id) into valid_count
  from unnest(p_member_ids) as requested(id)
  join public.profiles p on p.id = requested.id
  where requested.id <> current_user_id;

  if valid_count <> requested_count then
    raise exception 'One or more selected users are invalid';
  end if;

  insert into public.chat_rooms (id, name, room_type, created_by)
  values (group_room_id, trim(p_name), 'group', current_user_id);
  insert into public.chat_room_members (room_id, user_id)
  values (group_room_id, current_user_id);
  insert into public.chat_room_members (room_id, user_id)
  select group_room_id, requested.id
  from unnest(p_member_ids) as requested(id);
  return group_room_id;
end;
$$;

alter table public.messages enable row level security;
alter table public.profiles enable row level security;
alter table public.chat_rooms enable row level security;
alter table public.chat_room_members enable row level security;

drop policy if exists "Users read recent messages" on public.messages;
drop policy if exists "Admins read complete archive" on public.messages;
drop policy if exists "Users insert own messages" on public.messages;
drop policy if exists "Users read accessible recent messages" on public.messages;
drop policy if exists "Users insert accessible messages" on public.messages;

create policy "Users read accessible recent messages"
  on public.messages for select to authenticated
  using (
    created_at > now() - interval '24 hours'
    and public.is_chat_room_member(room_id)
  );

create policy "Admins read complete archive"
  on public.messages for select to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'admin@enchante.com');

create policy "Users insert accessible messages"
  on public.messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and lower(sender_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    and created_at > now() - interval '24 hours'
    and public.is_chat_room_member(room_id)
  );

drop policy if exists "Authenticated users search profiles" on public.profiles;
create policy "Authenticated users search profiles"
  on public.profiles for select to authenticated using (true);

drop policy if exists "Members read their rooms" on public.chat_rooms;
create policy "Members read their rooms"
  on public.chat_rooms for select to authenticated
  using (
    public.is_chat_room_member(id)
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'admin@enchante.com'
  );

drop policy if exists "Members read room membership" on public.chat_room_members;
create policy "Members read room membership"
  on public.chat_room_members for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_chat_room_member(room_id)
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'admin@enchante.com'
  );

grant select on public.profiles, public.chat_rooms, public.chat_room_members
  to authenticated;
grant select, insert on public.messages to authenticated;
revoke all on function public.is_chat_room_member(text) from public;
revoke all on function public.get_my_chat_rooms() from public;
revoke all on function public.start_direct_chat(uuid) from public;
revoke all on function public.create_group_chat(text, uuid[]) from public;
grant execute on function public.is_chat_room_member(text) to authenticated;
grant execute on function public.get_my_chat_rooms() to authenticated;
grant execute on function public.start_direct_chat(uuid) to authenticated;
grant execute on function public.create_group_chat(text, uuid[]) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'chat_room_members'
  ) then
    alter publication supabase_realtime add table public.chat_room_members;
  end if;
end;
$$;
```

The sign-in screen requires the existing account's 3–24 character username,
email, and password. It checks the username against that account's profile;
accounts must be provisioned outside the app (for example, in the Supabase
Dashboard) because in-app sign-up is disabled. The profile trigger assigns a
generated username if none is supplied when an account is provisioned. Existing
accounts also receive a generated username during the SQL migration; usernames
can be found in the `profiles` table and shared with users. The profile
directory is searchable only to authenticated users.
Direct conversations are created using a deterministic pair of user IDs, so
both people share the same private room. Group membership and direct-room
creation are performed through security definer RPCs; normal users cannot
directly add themselves to arbitrary rooms.

The administrator can view the complete message history using the configured
email `admin@enchante.com`; everyone else is limited to the last 24 hours in
rooms they belong to. Messages from the retired General room remain in the
admin archive but are no longer accessible in the user chat UI. Messages are
hidden after 24 hours, not physically deleted. Do not put a Supabase
`service_role` key in a web app.

## Run locally

Pass your Supabase URL and anon/public key at compile time:

```powershell
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Supabase persists successful sign-in sessions, and the browser can offer to
save credentials using its password manager. The app does not store raw
passwords itself.

## GitHub Pages

The workflow in `.github/workflows/deploy.yml` deploys on pushes to `main`.
Enable GitHub Pages with **GitHub Actions** as the source, and configure
repository Actions variables `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
