-- CruizX public gatherings, built on top of the existing convoy tables.
-- Run once in the Supabase SQL editor before releasing the matching app build.

alter table public.convoys
  add column if not exists visibility text not null default 'private',
  add column if not exists meetup_lat double precision,
  add column if not exists meetup_lng double precision,
  add column if not exists meetup_label text not null default '',
  add column if not exists ends_at timestamptz;

alter table public.convoy_locations
  add column if not exists vehicle_style text not null default 'navigation';

alter table public.convoys
  drop constraint if exists convoys_visibility_check;
alter table public.convoys
  add constraint convoys_visibility_check
  check (visibility in ('private', 'public'));

alter table public.convoys
  drop constraint if exists convoys_public_meetup_check;
alter table public.convoys
  add constraint convoys_public_meetup_check
  check (
    visibility = 'private'
    or (
      meetup_lat between -90 and 90
      and meetup_lng between -180 and 180
      and length(trim(meetup_label)) between 1 and 120
      and ends_at is not null
    )
  );

create index if not exists convoys_public_active_idx
  on public.convoys (ends_at desc, created_at desc)
  where visibility = 'public';

-- Public gatherings are discoverable by signed-in users. Convoy rows remain
-- readable to authenticated users so the existing private invite-code lookup
-- keeps working; the app only lists private convoys after membership is found.
drop policy if exists "convoys_select_authenticated" on public.convoys;
create policy "convoys_select_authenticated"
on public.convoys for select
to authenticated
using (true);

-- Live locations are only visible inside a gathering/convoy the user joined.
-- Sharing remains opt-in in the app for public gatherings.
drop policy if exists "convoy_locations_select_authenticated"
  on public.convoy_locations;
drop policy if exists "convoy_locations_select_members"
  on public.convoy_locations;
create policy "convoy_locations_select_members"
on public.convoy_locations for select
to authenticated
using (
  exists (
    select 1
    from public.convoy_members member
    where member.convoy_id = convoy_locations.convoy_id
      and member.user_id::text = auth.uid()::text
  )
);

drop policy if exists "convoy_locations_upsert_self"
  on public.convoy_locations;
drop policy if exists "convoy_locations_insert_self_member"
  on public.convoy_locations;
create policy "convoy_locations_insert_self_member"
on public.convoy_locations for insert
to authenticated
with check (
  auth.uid()::text = user_id::text
  and exists (
    select 1
    from public.convoy_members member
    where member.convoy_id = convoy_locations.convoy_id
      and member.user_id::text = auth.uid()::text
  )
);

drop policy if exists "convoy_locations_update_self"
  on public.convoy_locations;
drop policy if exists "convoy_locations_update_self_member"
  on public.convoy_locations;
create policy "convoy_locations_update_self_member"
on public.convoy_locations for update
to authenticated
using (auth.uid()::text = user_id::text)
with check (
  auth.uid()::text = user_id::text
  and exists (
    select 1
    from public.convoy_members member
    where member.convoy_id = convoy_locations.convoy_id
      and member.user_id::text = auth.uid()::text
  )
);

drop policy if exists "convoy_locations_delete_self"
  on public.convoy_locations;
create policy "convoy_locations_delete_self"
on public.convoy_locations for delete
to authenticated
using (auth.uid()::text = user_id::text);

-- Realtime publication is idempotent only via this guarded block.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'convoys'
  ) then
    alter publication supabase_realtime add table public.convoys;
  end if;
end $$;
