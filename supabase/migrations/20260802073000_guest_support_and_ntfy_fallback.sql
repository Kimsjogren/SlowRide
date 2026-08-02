-- Guest support conversations and a Supabase-origin ntfy fallback.

begin;

alter table public.support_messages
  alter column user_id drop not null,
  add column if not exists guest_token_hash text;

alter table public.support_messages
  drop constraint if exists support_messages_owner_check;
alter table public.support_messages
  add constraint support_messages_owner_check
  check (num_nonnulls(user_id, guest_token_hash) = 1);

alter table public.support_messages
  drop constraint if exists support_messages_guest_token_hash_check;
alter table public.support_messages
  add constraint support_messages_guest_token_hash_check
  check (guest_token_hash is null or guest_token_hash ~ '^[a-f0-9]{64}$');

create index if not exists support_messages_guest_created_idx
  on public.support_messages (guest_token_hash, created_at)
  where guest_token_hash is not null;

create or replace function public.insert_guest_support_message(
  p_guest_token_hash text,
  p_body text,
  p_language_code text default 'en'
)
returns public.support_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted public.support_messages;
  recent_count integer;
begin
  if p_guest_token_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'invalid_guest_token';
  end if;
  if length(trim(p_body)) not between 1 and 2000 then
    raise exception 'invalid_message_length';
  end if;
  if p_language_code not in ('sv', 'en', 'da', 'nb', 'fi', 'fr', 'es', 'it') then
    p_language_code := 'en';
  end if;

  select count(*)
    into recent_count
    from public.support_messages
   where guest_token_hash = p_guest_token_hash
     and sender = 'user'
     and created_at > now() - interval '10 minutes';

  if recent_count >= 5 then
    raise exception 'guest_message_rate_limit';
  end if;

  insert into public.support_messages (
    guest_token_hash,
    sender,
    body,
    language_code
  ) values (
    p_guest_token_hash,
    'user',
    trim(p_body),
    p_language_code
  )
  returning * into inserted;

  return inserted;
end;
$$;

revoke all on function public.insert_guest_support_message(text, text, text)
  from public, anon, authenticated;
grant execute on function public.insert_guest_support_message(text, text, text)
  to service_role;

create or replace function public.publish_support_ntfy(p_payload jsonb)
returns bigint
language plpgsql
security definer
set search_path = public, net
as $$
declare
  request_id bigint;
begin
  request_id := net.http_post(
    url := 'https://ntfy.sh',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := p_payload,
    timeout_milliseconds := 5000
  );
  return request_id;
end;
$$;

revoke all on function public.publish_support_ntfy(jsonb)
  from public, anon, authenticated;
grant execute on function public.publish_support_ntfy(jsonb)
  to service_role;

commit;
