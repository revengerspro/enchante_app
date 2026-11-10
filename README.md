# Enchanté

Enchanté is a Flutter web chat backed by Supabase Auth, Postgres, and Realtime.
Signed-in users can read the `general` room's last 24 hours; the designated
administrator can read its complete archive.

## Configure Supabase

Run the SQL below in the Supabase SQL Editor. The final statement enables
Postgres Changes for the app's realtime stream; skip it if `messages` is already
in the `supabase_realtime` publication.

```sql
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  text text not null check (char_length(text) between 1 and 10000),
  sender_id uuid not null references auth.users (id) on delete cascade,
  sender_email text not null,
  room_id text not null default 'general',
  created_at timestamptz not null default now()
);

create index if not exists messages_room_created_at_idx
  on public.messages (room_id, created_at);

alter table public.messages enable row level security;

drop policy if exists "Users read recent messages" on public.messages;
create policy "Users read recent messages"
  on public.messages for select
  to authenticated
  using (created_at > now() - interval '24 hours');

drop policy if exists "Admins read complete archive" on public.messages;
create policy "Admins read complete archive"
  on public.messages for select
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'admin@enchante.com');

drop policy if exists "Users insert own messages" on public.messages;
create policy "Users insert own messages"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = (select auth.uid())
    and lower(sender_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    and created_at > now() - interval '24 hours'
  );

grant select, insert on public.messages to authenticated;

alter publication supabase_realtime add table public.messages;
```

The admin email is checked against Supabase's signed JWT claim in the database
policy as well as in the UI. Do not use a Supabase `service_role` key in this
web app. For a different administrator, change `_adminEmail` in
`lib/main.dart` and the matching SQL policy value together.

## Run locally

Without build flags, local testing uses the Enchanté project URL and a
placeholder anon key so the sign-in UI opens. Supabase requests require a valid
key. To connect locally, supply your project's **Project URL** and **anon/public
key** at compile time:

```powershell
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

To build the web app locally:

```powershell
flutter build web --release --base-href "/enchante_app/" --dart-define=SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

The app uses one shared room named `general`; messages are not physically
deleted after 24 hours, but recent-only access is enforced with RLS and in the
user interface.

## GitHub Pages deployment

The workflow in `.github/workflows/deploy.yml` builds and deploys `build/web`
on pushes to `main`. Enable GitHub Pages with **GitHub Actions** as the build
and deployment source. Add repository Actions variables named `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
The workflow passes them as `--dart-define` arguments to the requested release
build command. Only the anon/public key belongs in the browser bundle; RLS must
remain enabled. Configure both variables for the deployed app to authenticate
and access chat data.
