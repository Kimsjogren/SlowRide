-- CruizX – Offer Code claim backend (Supabase / Postgres)
-- =========================================================
-- Kör i Supabase SQL editor.
-- Skapar två tabeller + en atomisk claim-funktion + RLS som
-- nekar all direktåtkomst (allt går via service_role i Worker).

-- 1. Koderna ---------------------------------------------------------
create table if not exists public.offer_codes (
  code              text primary key,
  campaign          text not null default 'Flyer2026',
  redeem_url        text not null,
  claimed_at        timestamptz,
  claimed_by_device text,
  claimed_by_ip     text,
  claimed_by_user   uuid references auth.users(id)
);

create index if not exists offer_codes_unclaimed_idx
  on public.offer_codes (campaign)
  where claimed_at is null;

-- 2. Event-logg (statistik) ------------------------------------------
create table if not exists public.flyer_events (
  id          bigserial primary key,
  kind        text not null,         -- 'scan' | 'claim' | 'claim_repeat' | 'sold_out'
  campaign    text not null default 'Flyer2026',
  device_hash text,
  ip          text,
  user_id     uuid references auth.users(id),
  meta        jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists flyer_events_created_idx on public.flyer_events (created_at desc);
create index if not exists flyer_events_kind_idx    on public.flyer_events (kind);

-- 3. Atomisk claim --------------------------------------------------
-- Tar nästa lediga kod (FOR UPDATE SKIP LOCKED = race-fri),
-- markerar den som claimad och returnerar code + redeem_url.
-- Om enheten redan har en kod i kampanjen → returnera den.

create or replace function public.claim_offer_code(
  p_campaign    text,
  p_device_hash text,
  p_ip          text,
  p_user_id     uuid default null
) returns table (code text, redeem_url text, repeat boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code        text;
  v_url         text;
begin
  -- Har enheten redan en kod i denna kampanj? återanvänd
  select oc.code, oc.redeem_url
    into v_code, v_url
    from offer_codes oc
   where oc.campaign = p_campaign
     and oc.claimed_by_device = p_device_hash
   limit 1;

  if v_code is not null then
    insert into flyer_events (kind, campaign, device_hash, ip, user_id, meta)
      values ('claim_repeat', p_campaign, p_device_hash, p_ip, p_user_id,
              jsonb_build_object('code', v_code));
    return query select v_code, v_url, true;
    return;
  end if;

  -- Plocka nästa lediga, lås raden så att två requests inte tar samma
  with picked as (
    select oc.code
      from offer_codes oc
     where oc.campaign = p_campaign
       and oc.claimed_at is null
     order by oc.code
     for update skip locked
     limit 1
  )
  update offer_codes oc
     set claimed_at        = now(),
         claimed_by_device = p_device_hash,
         claimed_by_ip     = p_ip,
         claimed_by_user   = p_user_id
   from picked
   where oc.code = picked.code
  returning oc.code, oc.redeem_url
   into v_code, v_url;

  if v_code is null then
    insert into flyer_events (kind, campaign, device_hash, ip, user_id)
      values ('sold_out', p_campaign, p_device_hash, p_ip, p_user_id);
    return;
  end if;

  insert into flyer_events (kind, campaign, device_hash, ip, user_id, meta)
    values ('claim', p_campaign, p_device_hash, p_ip, p_user_id,
            jsonb_build_object('code', v_code));

  return query select v_code, v_url, false;
end;
$$;

-- 4. Statistik-vy -----------------------------------------------------
create or replace view public.flyer_stats as
  select
    campaign,
    (select count(*) from offer_codes oc where oc.campaign = c.campaign) as total_codes,
    (select count(*) from offer_codes oc where oc.campaign = c.campaign and claimed_at is not null) as claimed_codes,
    (select count(*) from flyer_events fe where fe.campaign = c.campaign and kind = 'scan')         as scans,
    (select count(*) from flyer_events fe where fe.campaign = c.campaign and kind = 'claim')        as new_claims,
    (select count(*) from flyer_events fe where fe.campaign = c.campaign and kind = 'claim_repeat') as repeat_views
  from (select distinct campaign from offer_codes) c;

-- 5. Lås ner — bara service_role får läsa/skriva ----------------------
alter table public.offer_codes  enable row level security;
alter table public.flyer_events enable row level security;
-- (Ingen policy = inga rättigheter för anon/authenticated. Workern
--  använder service_role-nyckeln, som bypassar RLS.)

-- 6. Web subscription-entitlements -------------------------------------
-- Den här tabellen används av Flutter-webbappen för att avgöra om
-- användaren ska vara Pro efter lyckad webbetalning.

create table if not exists public.web_subscriptions (
  id                 bigserial primary key,
  user_id            uuid not null references auth.users(id) on delete cascade,
  provider           text not null default 'stripe',
  external_customer  text,
  external_sub       text unique,
  status             text not null default 'inactive',
  current_period_end timestamptz,
  updated_at         timestamptz not null default now(),
  created_at         timestamptz not null default now()
);

create unique index if not exists web_subscriptions_user_provider_uidx
  on public.web_subscriptions (user_id, provider);

create index if not exists web_subscriptions_status_idx
  on public.web_subscriptions (status, current_period_end desc);

create or replace function public.touch_web_subscriptions_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_web_subscriptions_updated_at on public.web_subscriptions;
create trigger trg_web_subscriptions_updated_at
before update on public.web_subscriptions
for each row execute function public.touch_web_subscriptions_updated_at();

alter table public.web_subscriptions enable row level security;

drop policy if exists "web_subscriptions_select_own" on public.web_subscriptions;
create policy "web_subscriptions_select_own"
on public.web_subscriptions
for select
to authenticated
using (auth.uid() = user_id);

-- Skrivning görs från webhook/backend med service_role, inte från klienten.
