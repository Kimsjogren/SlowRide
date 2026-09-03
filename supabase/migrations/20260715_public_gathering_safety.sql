-- Scheduling, organizer controls and safety tools for public gatherings.
-- Run once after 20260715_public_gatherings.sql.

begin;

alter table public.convoys
  add column if not exists starts_at timestamptz;

update public.convoys
set starts_at = created_at
where starts_at is null;

alter table public.convoys
  alter column starts_at set default now(),
  alter column starts_at set not null;

alter table public.convoys
  drop constraint if exists convoys_public_schedule_check;
alter table public.convoys
  add constraint convoys_public_schedule_check
  check (visibility = 'private' or ends_at > starts_at);

drop policy if exists "convoys_update_authenticated" on public.convoys;
drop policy if exists "convoys_update_leader" on public.convoys;
create policy "convoys_update_leader"
on public.convoys for update
to authenticated
using (auth.uid()::text = leader_id::text)
with check (auth.uid()::text = leader_id::text);

drop policy if exists "convoys_delete_leader" on public.convoys;
create policy "convoys_delete_leader"
on public.convoys for delete
to authenticated
using (auth.uid()::text = leader_id::text);

create table if not exists public.convoy_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id text not null,
  target_type text not null check (target_type in ('gathering', 'participant')),
  -- Stored as text because older CruizX installations may use either text or
  -- uuid for convoys.id. App/API comparisons remain type-safe this way.
  gathering_id text not null,
  target_user_id text,
  reason text not null check (reason in ('inappropriate', 'harassment', 'dangerous', 'spam', 'other')),
  details text not null default '',
  created_at timestamptz not null default now(),
  check (
    (target_type = 'gathering' and target_user_id is null)
    or (target_type = 'participant' and target_user_id is not null)
  )
);

-- Repair a table left behind by an earlier version of this migration.
alter table public.convoy_reports
  drop constraint if exists convoy_reports_gathering_id_fkey;
alter table public.convoy_reports
  alter column gathering_id type text using gathering_id::text;

create index if not exists convoy_reports_gathering_idx
  on public.convoy_reports (gathering_id, created_at desc);

alter table public.convoy_reports enable row level security;
drop policy if exists "convoy_reports_insert_self" on public.convoy_reports;
create policy "convoy_reports_insert_self"
on public.convoy_reports for insert
to authenticated
with check (auth.uid()::text = reporter_id::text);
drop policy if exists "convoy_reports_select_self" on public.convoy_reports;
create policy "convoy_reports_select_self"
on public.convoy_reports for select
to authenticated
using (auth.uid()::text = reporter_id::text);

create table if not exists public.convoy_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id text not null,
  target_type text not null check (target_type in ('gathering', 'participant')),
  gathering_id text,
  blocked_user_id text,
  created_at timestamptz not null default now(),
  check (
    (target_type = 'gathering' and gathering_id is not null and blocked_user_id is null)
    or (target_type = 'participant' and blocked_user_id is not null)
  )
);

-- Repair a table left behind by an earlier version of this migration.
alter table public.convoy_blocks
  drop constraint if exists convoy_blocks_gathering_id_fkey;
alter table public.convoy_blocks
  alter column gathering_id type text using gathering_id::text;

create unique index if not exists convoy_blocks_gathering_unique
  on public.convoy_blocks (blocker_id, gathering_id)
  where target_type = 'gathering';
create unique index if not exists convoy_blocks_participant_unique
  on public.convoy_blocks (blocker_id, blocked_user_id)
  where target_type = 'participant';

alter table public.convoy_blocks enable row level security;
drop policy if exists "convoy_blocks_select_self" on public.convoy_blocks;
create policy "convoy_blocks_select_self"
on public.convoy_blocks for select
to authenticated
using (auth.uid()::text = blocker_id::text);
drop policy if exists "convoy_blocks_insert_self" on public.convoy_blocks;
create policy "convoy_blocks_insert_self"
on public.convoy_blocks for insert
to authenticated
with check (auth.uid()::text = blocker_id::text);
drop policy if exists "convoy_blocks_delete_self" on public.convoy_blocks;
create policy "convoy_blocks_delete_self"
on public.convoy_blocks for delete
to authenticated
using (auth.uid()::text = blocker_id::text);

create index if not exists convoys_public_schedule_idx
  on public.convoys (starts_at, ends_at)
  where visibility = 'public';

-- Text-based gathering references cannot use a cross-type foreign key. Keep
-- them tidy when an organizer deletes a gathering through a small trigger.
create or replace function public.cleanup_convoy_safety_rows()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.convoy_reports where gathering_id = old.id::text;
  delete from public.convoy_blocks where gathering_id = old.id::text;
  return old;
end;
$$;

drop trigger if exists cleanup_convoy_safety_rows_trigger on public.convoys;
create trigger cleanup_convoy_safety_rows_trigger
before delete on public.convoys
for each row execute function public.cleanup_convoy_safety_rows();

commit;
