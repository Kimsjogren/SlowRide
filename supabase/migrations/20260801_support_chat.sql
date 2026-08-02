-- Private one-to-one support chat for authenticated CruizX users.

begin;

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  sender text not null check (sender in ('user', 'support')),
  body text not null check (length(trim(body)) between 1 and 2000),
  language_code text not null default 'en'
    check (language_code in ('sv', 'en', 'da', 'nb', 'fi', 'fr', 'es', 'it')),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists support_messages_user_created_idx
  on public.support_messages (user_id, created_at);

alter table public.support_messages enable row level security;

drop policy if exists "support_messages_select_own" on public.support_messages;
create policy "support_messages_select_own"
on public.support_messages for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "support_messages_insert_own" on public.support_messages;
create policy "support_messages_insert_own"
on public.support_messages for insert
to authenticated
with check (auth.uid() = user_id and sender = 'user');

drop policy if exists "support_messages_mark_support_read"
  on public.support_messages;

create or replace function public.mark_support_messages_read()
returns void
language sql
security definer
set search_path = public
as $$
  update public.support_messages
  set read_at = now()
  where user_id = auth.uid()
    and sender = 'support'
    and read_at is null;
$$;

revoke all on function public.mark_support_messages_read() from public;
revoke all on function public.mark_support_messages_read() from anon;
grant execute on function public.mark_support_messages_read()
  to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'support_messages'
  ) then
    alter publication supabase_realtime
      add table public.support_messages;
  end if;
end $$;

commit;
