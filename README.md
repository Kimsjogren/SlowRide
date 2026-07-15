# SlowRide

Navigation app for slow vehicles such as A-tractors, moped cars, and tractors.

## Quick start

1. Install Flutter stable.
2. Run dependencies:

```bash
flutter pub get
```

3. Start the app:

```bash
flutter run
```

## Current status

- Flutter project scaffold created
- Feature-first `lib/` structure in place
- App shell with bottom navigation (Map, Alerts, Convoy, Profile, Settings)
- Placeholder models, services, and widgets ready for implementation

## Cost policy (MVP)

- Start with zero monthly cost
- Map: OpenStreetMap tiles via `flutter_map`
- GPS: `geolocator`
- Keep paid APIs optional until users/traffic justify upgrade

## Best free routing alternatives

- **Default now:** OSRM public demo (`router.project-osrm.org`) for snabb start utan nyckel
- **Best long-term free:** Self-hosted OSRM (ingen API-kostnad, full kontroll)
- **Best free tier:** OpenRouteService (nyckel, gratisnivå med begränsningar)

## Backend-only configuration

- Användare väljer inte routing provider i appens UI
- All providerstyrning sker via backend/dev-konfiguration med `--dart-define`
- Stöd finns för `osrm_public` (default), `osrm_self_hosted`, `openrouteservice`
- Frontend settings används enbart för användarval (fordonstyp, enhet, maxhastighet)
- Convoy Mode kräver att användaren är inloggad
- Slow vehicle routing är strikt som standard (`STRICT_SLOW_VEHICLE_ROUTING=true`)
- Fordonstyp i appen styr vilken vägbegränsning som används vid ruttberäkning
- En extra spärr stoppar rutter vars beräknade medelhastighet är för hög för vald fordonstyp

Exempel:

```bash
flutter run --dart-define=ROUTING_PROVIDER=osrm_self_hosted --dart-define=OSRM_BASE_URL=https://din-osrm-server
```

```bash
flutter run --dart-define=ROUTING_PROVIDER=openrouteservice --dart-define=ORS_API_KEY=din_nyckel
```

Obs: Begränsningen är fail-closed i appen: om en rutt inte uppfyller slow-vehicle-reglerna visas den inte alls.

## Supabase OTP + Realtime (recommended)

- Convoy realtime mellan olika användare kräver backend. Rekommenderad gratisväg är Supabase Free.
- Inloggning sker med e-post OTP (engångskod), inte lösenord.
- Frontend exponerar inga tekniska provider-val.

Kör appen med backend-konfig:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Utan dessa värden kör appen i lokalt fallback-läge (ingen cross-device realtime).

### Secure SQL setup (Supabase)

For an existing CruizX database, run
[`supabase/migrations/20260715_public_gatherings.sql`](supabase/migrations/20260715_public_gatherings.sql)
in the Supabase SQL editor. It adds public gatherings, meetup locations,
optional participant vehicle markers, and member-only live-location policies.
Then run
[`supabase/migrations/20260715_public_gathering_safety.sql`](supabase/migrations/20260715_public_gathering_safety.sql)
to add start/end scheduling, organizer end/delete permissions, reports and
user-owned gathering/participant blocks.

Skapa tabell + aktivera RLS i SQL Editor:

```sql
create table if not exists public.convoys (
	id uuid primary key default gen_random_uuid(),
	name text not null,
	leader_id uuid not null references auth.users(id) on delete cascade,
	created_at timestamptz not null default now()
);

create table if not exists public.convoy_members (
	convoy_id uuid not null references public.convoys(id) on delete cascade,
	user_id uuid not null references auth.users(id) on delete cascade,
	joined_at timestamptz not null default now(),
	primary key (convoy_id, user_id)
);

create table if not exists public.convoy_messages (
	id uuid primary key default gen_random_uuid(),
	convoy_id uuid not null references public.convoys(id) on delete cascade,
	user_id uuid not null references auth.users(id) on delete cascade,
	user_label text not null,
	text text not null,
	created_at timestamptz not null default now()
);

create table if not exists public.convoy_locations (
	convoy_id uuid not null references public.convoys(id) on delete cascade,
	user_id uuid not null references auth.users(id) on delete cascade,
	user_label text not null,
	lat double precision not null,
	lng double precision not null,
	updated_at timestamptz not null default now(),
	primary key (convoy_id, user_id)
);

create table if not exists public.convoy_pins (
	id uuid primary key default gen_random_uuid(),
	convoy_id uuid not null references public.convoys(id) on delete cascade,
	user_id uuid not null references auth.users(id) on delete cascade,
	user_label text not null,
	label text not null,
	type text not null default 'custom',
	lat double precision not null,
	lng double precision not null,
	created_at timestamptz not null default now()
);

alter table public.convoys enable row level security;
alter table public.convoy_members enable row level security;
alter table public.convoy_messages enable row level security;
alter table public.convoy_locations enable row level security;
alter table public.convoy_pins enable row level security;

drop policy if exists "convoys_select_authenticated" on public.convoys;
create policy "convoys_select_authenticated"
on public.convoys for select
to authenticated
using (true);

drop policy if exists "convoys_insert_own_leader" on public.convoys;
create policy "convoys_insert_own_leader"
on public.convoys for insert
to authenticated
with check (auth.uid() = leader_id);

drop policy if exists "convoys_update_authenticated" on public.convoys;
create policy "convoys_update_authenticated"
on public.convoys for update
to authenticated
using (true)
with check (auth.uid() = leader_id);

drop policy if exists "convoy_members_select_authenticated" on public.convoy_members;
create policy "convoy_members_select_authenticated"
on public.convoy_members for select
to authenticated
using (true);

drop policy if exists "convoy_members_insert_self" on public.convoy_members;
create policy "convoy_members_insert_self"
on public.convoy_members for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "convoy_members_delete_self" on public.convoy_members;
create policy "convoy_members_delete_self"
on public.convoy_members for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists "convoy_messages_select_authenticated" on public.convoy_messages;
create policy "convoy_messages_select_authenticated"
on public.convoy_messages for select
to authenticated
using (true);

drop policy if exists "convoy_messages_insert_self" on public.convoy_messages;
create policy "convoy_messages_insert_self"
on public.convoy_messages for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "convoy_locations_select_authenticated" on public.convoy_locations;
create policy "convoy_locations_select_authenticated"
on public.convoy_locations for select
to authenticated
using (true);

drop policy if exists "convoy_locations_upsert_self" on public.convoy_locations;
create policy "convoy_locations_upsert_self"
on public.convoy_locations for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "convoy_locations_update_self" on public.convoy_locations;
create policy "convoy_locations_update_self"
on public.convoy_locations for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "convoy_pins_select_authenticated" on public.convoy_pins;
create policy "convoy_pins_select_authenticated"
on public.convoy_pins for select
to authenticated
using (true);

drop policy if exists "convoy_pins_insert_self" on public.convoy_pins;
create policy "convoy_pins_insert_self"
on public.convoy_pins for insert
to authenticated
with check (auth.uid() = user_id);
```

I Supabase Dashboard:
- Auth → Providers: Email aktivt.
- Auth → Email OTP: aktivera OTP code flow.
- Behåll endast `anon` key i appen (aldrig `service_role`).

Obs:
- Incidentmarkeringar (t.ex. polis, vägarbete, olycka) döljs automatiskt i appen efter 30 minuter.

## Next implementation steps

- Improve OpenStreetMap map layer in `features/map`
- Add GPS tracking + speedometer data flow
- Move provider setup fully to backend/deployment config
- Implement alerts and convoy real-time sync
