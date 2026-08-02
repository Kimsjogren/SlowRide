-- Notify the CruizX backend asynchronously when a user sends support chat.
-- Runtime values are read from Supabase Vault and never stored in source.

begin;

create extension if not exists pg_net with schema extensions;

create or replace function public.notify_support_message_ntfy()
returns trigger
language plpgsql
security definer
set search_path = public, vault, net
as $$
declare
  webhook_url text;
  webhook_secret text;
begin
  select decrypted_secret
    into webhook_url
    from vault.decrypted_secrets
   where name = 'support_webhook_url'
   limit 1;

  select decrypted_secret
    into webhook_secret
    from vault.decrypted_secrets
   where name = 'support_webhook_secret'
   limit 1;

  if webhook_url is null or webhook_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := webhook_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-CruizX-Webhook-Secret', webhook_secret
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'support_messages',
      'schema', 'public',
      'record', to_jsonb(new)
    ),
    timeout_milliseconds := 5000
  );

  return new;
end;
$$;

revoke all on function public.notify_support_message_ntfy() from public;
revoke all on function public.notify_support_message_ntfy() from anon;
revoke all on function public.notify_support_message_ntfy() from authenticated;

drop trigger if exists support_messages_ntfy_after_insert
  on public.support_messages;
create trigger support_messages_ntfy_after_insert
after insert on public.support_messages
for each row
when (new.sender = 'user')
execute function public.notify_support_message_ntfy();

commit;
