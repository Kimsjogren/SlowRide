/*
 * CruizX claim API — Cloudflare Worker
 * ---------------------------------------------------------------
 * Routes:
 *   POST /api/claim   → returnerar { code, redeem_url, repeat }
 *   POST /api/scan    → logga en QR-scan (no-op om redan loggad)
 *   GET  /api/stats   → enkel översikt (skyddad med STATS_TOKEN)
 *   GET  /api/web/pricing          → läs aktivt Stripe-pris för webb/APK
 *   GET  /api/map/speed-bumps      → cachelagrade farthinder från OpenStreetMap
 *   POST /api/web/checkout-session → skapa Stripe Checkout Session (subscription)
 *   POST /api/web/stripe-webhook   → uppdatera web_subscriptions i Supabase
 *
 * Säkerhet:
 *   - Service-key bor i Worker-secrets (wrangler secret put …),
 *     ALDRIG i klienten.
 *   - Enheter hashas (SHA-256 av cookie + IP + UA) så vi inte
 *     spar PII i klartext.
 *   - CORS låses till tillåtna origins.
 */

const ALLOWED_ORIGINS = new Set([
  "https://cruizx.com",
  "https://www.cruizx.com",
  "http://localhost:8000",
  "http://127.0.0.1:8000",
]);

const DEVICE_COOKIE = "cx_did";
const DEVICE_COOKIE_MAX_AGE = 60 * 60 * 24 * 365; // 1 år

function corsHeaders(origin) {
  const allow = ALLOWED_ORIGINS.has(origin) ? origin : "https://cruizx.com";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Credentials": "true",
    "Vary": "Origin",
  };
}

function json(body, init = {}, origin = "") {
  const mergedHeaders = {
    "Content-Type": "application/json",
    ...corsHeaders(origin),
  };
  if (init.headers) {
    Object.assign(mergedHeaders, init.headers);
  }

  return new Response(JSON.stringify(body), {
    ...init,
    headers: mergedHeaders,
  });
}

async function sha256Hex(input) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function readCookie(request, name) {
  const header = request.headers.get("Cookie") || "";
  for (const part of header.split(/;\s*/)) {
    const [k, ...v] = part.split("=");
    if (k === name) return decodeURIComponent(v.join("="));
  }
  return null;
}

function makeDeviceId() {
  return crypto.randomUUID().replaceAll("-", "");
}

async function deviceHash(request, deviceId, env) {
  const ip = request.headers.get("CF-Connecting-IP") || "";
  const ua = request.headers.get("User-Agent") || "";
  return sha256Hex(`${env.DEVICE_SALT}|${deviceId}|${ip}|${ua}`);
}

// --- Cloudflare Turnstile -----------------------------------------
async function verifyTurnstile(token, ip, env) {
  if (!token) return false;
  const form = new FormData();
  form.append("secret", env.TURNSTILE_SECRET);
  form.append("response", token);
  if (ip) form.append("remoteip", ip);
  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    body: form,
  });
  if (!res.ok) return false;
  const data = await res.json();
  return Boolean(data.success);
}

// --- Supabase RPC ---------------------------------------------------
async function supabaseRpc(env, fn, payload) {
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
      "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify(payload),
  });
  if (!res.ok) throw new Error(`Supabase ${fn} ${res.status}: ${await res.text()}`);
  return res.json();
}

async function logEvent(env, kind, campaign, deviceHashHex, ip, meta) {
  await fetch(`${env.SUPABASE_URL}/rest/v1/flyer_events`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
      "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      "Prefer": "return=minimal",
    },
    body: JSON.stringify([{ kind, campaign, device_hash: deviceHashHex, ip, meta }]),
  });
}

function isUuid(value) {
  return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function stripeFormBody(params) {
  const form = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === null || value === undefined) continue;
    form.append(key, String(value));
  }
  return form;
}

const PRICE_LOCALES = ["en", "sv", "nb", "da", "fi", "fr", "es"];

const INTERVAL_LABELS = {
  day: { en: "day", sv: "dag", nb: "dag", da: "dag", fi: "päivä", fr: "jour", es: "día" },
  week: { en: "week", sv: "vecka", nb: "uke", da: "uge", fi: "viikko", fr: "semaine", es: "semana" },
  month: { en: "month", sv: "månad", nb: "måned", da: "måned", fi: "kuukausi", fr: "mois", es: "mes" },
  year: { en: "year", sv: "år", nb: "år", da: "år", fi: "vuosi", fr: "an", es: "año" },
};

function formatAmountForLocale(locale, amountMinor, currency) {
  const zeroDecimalCurrencies = new Set([
    "bif", "clp", "djf", "gnf", "jpy", "kmf", "krw", "mga",
    "pyg", "rwf", "ugx", "vnd", "vuv", "xaf", "xof", "xpf",
  ]);
  const fractionDigits = zeroDecimalCurrencies.has(currency.toLowerCase()) ? 0 : 2;
  return new Intl.NumberFormat(locale, {
    style: "currency",
    currency: currency.toUpperCase(),
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: fractionDigits,
  }).format(amountMinor / Math.pow(10, fractionDigits));
}

function buildLocalizedPricePayload(price) {
  const amountMinor = Number(price?.unit_amount ?? 0);
  const currency = (price?.currency || "sek").toLowerCase();
  const interval = price?.recurring?.interval || "month";
  const intervalCount = Number(price?.recurring?.interval_count || 1);
  const labels = INTERVAL_LABELS[interval] || INTERVAL_LABELS.month;

  const amountByLocale = {};
  const displayByLocale = {};

  for (const locale of PRICE_LOCALES) {
    const amountLabel = formatAmountForLocale(locale, amountMinor, currency);
    amountByLocale[locale] = amountLabel;
    const intervalLabel = labels[locale] || labels.en;
    displayByLocale[locale] = intervalCount > 1
      ? `${amountLabel} / ${intervalCount} ${intervalLabel}`
      : `${amountLabel} / ${intervalLabel}`;
  }

  return {
    stripe_price_id: price.id,
    amount_minor: amountMinor,
    currency,
    interval,
    interval_count: intervalCount,
    amount_by_locale: amountByLocale,
    display_by_locale: displayByLocale,
  };
}

async function stripeApiPost(env, path, params) {
  const body = stripeFormBody(params);
  const res = await fetch(`https://api.stripe.com/v1${path}`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });
  const data = await res.json();
  if (!res.ok) {
    const detail = data?.error?.message || `Stripe ${res.status}`;
    throw new Error(detail);
  }
  return data;
}

async function stripeApiGet(env, path) {
  const res = await fetch(`https://api.stripe.com/v1${path}`, {
    method: "GET",
    headers: {
      "Authorization": `Bearer ${env.STRIPE_SECRET_KEY}`,
    },
  });
  const data = await res.json();
  if (!res.ok) {
    const detail = data?.error?.message || `Stripe ${res.status}`;
    throw new Error(detail);
  }
  return data;
}

async function handleWebPricing(env, origin) {
  if (!env.STRIPE_SECRET_KEY || !env.STRIPE_PRICE_ID) {
    return json({ error: "stripe_not_configured" }, { status: 500 }, origin);
  }

  try {
    const price = await stripeApiGet(
      env,
      `/prices/${encodeURIComponent(env.STRIPE_PRICE_ID)}`
    );
    return json(
      {
        status: "ok",
        pricing: buildLocalizedPricePayload(price),
      },
      { status: 200 },
      origin
    );
  } catch (e) {
    return json(
      { error: "stripe_price_lookup_failed", detail: String(e) },
      { status: 500 },
      origin
    );
  }
}

function constantTimeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i += 1) {
    out |= (a.codePointAt(i) ?? 0) ^ (b.codePointAt(i) ?? 0);
  }
  return out === 0;
}

function parseStripeSignature(header) {
  const parsed = { t: null, v1: [] };
  if (!header) return parsed;
  for (const part of header.split(",")) {
    const [k, v] = part.split("=");
    if (k === "t") parsed.t = v;
    if (k === "v1") parsed.v1.push(v);
  }
  return parsed;
}

async function hmacSha256Hex(secret, payload) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function verifyStripeWebhook(request, env, rawBody) {
  const header = request.headers.get("Stripe-Signature");
  const { t, v1 } = parseStripeSignature(header);
  if (!t || !Array.isArray(v1) || v1.length === 0) return false;

  const age = Math.abs(Math.floor(Date.now() / 1000) - Number(t));
  if (!Number.isFinite(age) || age > 300) return false;

  const expected = await hmacSha256Hex(env.STRIPE_WEBHOOK_SECRET, `${t}.${rawBody}`);
  return v1.some((candidate) => constantTimeEqual(candidate, expected));
}

async function upsertWebSubscription(env, row) {
  const res = await fetch(
    `${env.SUPABASE_URL}/rest/v1/web_subscriptions?on_conflict=user_id,provider`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        "Prefer": "resolution=merge-duplicates,return=minimal",
      },
      body: JSON.stringify([row]),
    }
  );
  if (!res.ok) {
    throw new Error(`Supabase web_subscriptions upsert ${res.status}: ${await res.text()}`);
  }
}

async function loadUserIdByExternalSub(env, externalSub) {
  const url = `${env.SUPABASE_URL}/rest/v1/web_subscriptions?select=user_id&external_sub=eq.${encodeURIComponent(externalSub)}&limit=1`;
  const res = await fetch(url, {
    headers: {
      "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
      "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
    },
  });
  if (!res.ok) return null;
  const rows = await res.json();
  if (!Array.isArray(rows) || rows.length === 0) return null;
  return rows[0]?.user_id || null;
}

function unixToIsoMaybe(unixSeconds) {
  if (!Number.isFinite(unixSeconds)) return null;
  return new Date(unixSeconds * 1000).toISOString();
}

async function handleWebCheckoutSession(request, env, origin) {
  if (!env.STRIPE_SECRET_KEY || !env.STRIPE_PRICE_ID) {
    return json({ error: "stripe_not_configured" }, { status: 500 }, origin);
  }

  let body = {};
  try { body = await request.json(); } catch {}

  const uid = (body.uid || "").toString().trim();
  const email = (body.email || "").toString().trim().toLowerCase();
  // uid is optional when purchasing from website (not from the app)

  const successUrl = env.WEB_CHECKOUT_SUCCESS_URL || "https://cruizx.com/get-app?checkout=success";
  const cancelUrl = env.WEB_CHECKOUT_CANCEL_URL || "https://cruizx.com/get-app?checkout=cancel";

  try {
    const session = await stripeApiPost(env, "/checkout/sessions", {
      mode: "subscription",
      "line_items[0][price]": env.STRIPE_PRICE_ID,
      "line_items[0][quantity]": 1,
      success_url: successUrl,
      cancel_url: cancelUrl,
      ...(isUuid(uid) ? {
        client_reference_id: uid,
        "metadata[uid]": uid,
        "subscription_data[metadata][uid]": uid,
      } : {}),
      ...(email ? { customer_email: email } : {}),
    });

    return json(
      {
        status: "ok",
        id: session.id,
        url: session.url,
      },
      { status: 200 },
      origin
    );
  } catch (e) {
    return json({ error: "stripe_checkout_failed", detail: String(e) }, { status: 500 }, origin);
  }
}

async function syncSubscriptionFromStripe(env, stripeSub, fallbackUid = null) {
  if (!stripeSub?.id) return;

  const uidFromMetadata =
    stripeSub?.metadata?.uid ||
    stripeSub?.items?.data?.[0]?.metadata?.uid ||
    null;
  const userId = uidFromMetadata || fallbackUid || await loadUserIdByExternalSub(env, stripeSub.id);
  if (!isUuid(userId)) {
    return;
  }

  const row = {
    user_id: userId,
    provider: "stripe",
    external_customer: stripeSub.customer || null,
    external_sub: stripeSub.id,
    status: stripeSub.status || "inactive",
    current_period_end: unixToIsoMaybe(stripeSub.current_period_end),
  };
  await upsertWebSubscription(env, row);
}

async function handleStripeWebhook(request, env) {
  if (!env.STRIPE_WEBHOOK_SECRET || !env.STRIPE_SECRET_KEY) {
    return new Response("stripe webhook not configured", { status: 500 });
  }

  const rawBody = await request.text();
  const valid = await verifyStripeWebhook(request, env, rawBody);
  if (!valid) {
    return new Response("invalid signature", { status: 400 });
  }

  let event;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response("invalid json", { status: 400 });
  }

  try {
    const type = event?.type;
    const object = event?.data?.object;

    if (type === "checkout.session.completed" && object?.mode === "subscription") {
      const uid = object?.metadata?.uid || object?.client_reference_id || null;
      if (object?.subscription) {
        const sub = await stripeApiGet(env, `/subscriptions/${encodeURIComponent(object.subscription)}`);
        await syncSubscriptionFromStripe(env, sub, uid);
      }
    }

    if (type === "customer.subscription.created" || type === "customer.subscription.updated") {
      await syncSubscriptionFromStripe(env, object, null);
    }

    if (type === "customer.subscription.deleted") {
      const userId = object?.metadata?.uid || await loadUserIdByExternalSub(env, object?.id);
      if (isUuid(userId)) {
        await upsertWebSubscription(env, {
          user_id: userId,
          provider: "stripe",
          external_customer: object?.customer || null,
          external_sub: object?.id || null,
          status: "canceled",
          current_period_end: unixToIsoMaybe(object?.current_period_end),
        });
      }
    }

    return new Response("ok", { status: 200 });
  } catch (e) {
    return new Response(`webhook processing failed: ${String(e)}`, { status: 500 });
  }
}

// --- Handlers -------------------------------------------------------

async function handleClaim(request, env, origin) {
  let body = {};
  try { body = await request.json(); } catch {}
  const campaign = (body.campaign || "Flyer2026").toString().slice(0, 64);

  const ip = request.headers.get("CF-Connecting-IP") || "";

  // Verifiera Turnstile innan vi gör något annat
  const ok = await verifyTurnstile(body.turnstileToken, ip, env);
  if (!ok) {
    return json({ error: "turnstile_failed" }, { status: 403 }, origin);
  }

  let deviceId = readCookie(request, DEVICE_COOKIE);
  let setCookie = null;
  if (!deviceId) {
    deviceId = makeDeviceId();
    setCookie = `${DEVICE_COOKIE}=${deviceId}; Max-Age=${DEVICE_COOKIE_MAX_AGE}; Path=/; SameSite=Lax; Secure; HttpOnly`;
  }

  const dHash = await deviceHash(request, deviceId, env);

  // IP-spärr: max 1 kod per IP per 24h. Samma device får alltid tillbaka sin egen kod.
  if (ip) {
    try {
      const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
      const checkUrl = `${env.SUPABASE_URL}/rest/v1/offer_codes` +
        `?select=claimed_by_device,claimed_at` +
        `&campaign=eq.${encodeURIComponent(campaign)}` +
        `&claimed_by_ip=eq.${encodeURIComponent(ip)}` +
        `&claimed_at=gte.${encodeURIComponent(since)}` +
        `&limit=5`;
      const checkRes = await fetch(checkUrl, {
        headers: {
          "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
          "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        },
      });
      if (checkRes.ok) {
        const rows = await checkRes.json();
        const otherDevice = Array.isArray(rows) &&
          rows.some((r) => r.claimed_by_device && r.claimed_by_device !== dHash);
        if (otherDevice) {
          return json(
            { error: "ip_rate_limited", message: "Den här nätverksanslutningen har redan hämtat en kod." },
            { status: 429 },
            origin
          );
        }
      }
    } catch {
      // fail-open: om kollen kraschar, släpp igenom (DB-locket skyddar fortfarande mot dubbletter)
    }
  }

  let result;
  try {
    result = await supabaseRpc(env, "claim_offer_code", {
      p_campaign:    campaign,
      p_device_hash: dHash,
      p_ip:          ip,
      p_user_id:     null,
    });
  } catch (err) {
    return json({ error: "internal_error", detail: String(err) }, { status: 500 }, origin);
  }

  const row = Array.isArray(result) ? result[0] : null;
  const headers = setCookie ? { "Set-Cookie": setCookie } : {};

  if (!row) {
    return json({ status: "sold_out" }, { status: 410, headers }, origin);
  }

  return json(
    { status: "ok", code: row.code, redeem_url: row.redeem_url, repeat: row.repeat },
    { headers },
    origin
  );
}

async function handleScan(request, env, origin) {
  let deviceId = readCookie(request, DEVICE_COOKIE);
  let setCookie = null;
  if (!deviceId) {
    deviceId = makeDeviceId();
    setCookie = `${DEVICE_COOKIE}=${deviceId}; Max-Age=${DEVICE_COOKIE_MAX_AGE}; Path=/; SameSite=Lax; Secure; HttpOnly`;
  }
  const ip = request.headers.get("CF-Connecting-IP") || "";
  const dHash = await deviceHash(request, deviceId, env);
  await logEvent(env, "scan", "Flyer2026", dHash, ip, null);
  return json({ status: "ok" }, { headers: setCookie ? { "Set-Cookie": setCookie } : {} }, origin);
}

async function handleStats(request, env, origin) {
  const token = request.headers.get("X-Stats-Token");
  if (!token || token !== env.STATS_TOKEN) {
    return json({ error: "unauthorized" }, { status: 401 }, origin);
  }
  const [flyerRes, apkRes] = await Promise.all([
    fetch(`${env.SUPABASE_URL}/rest/v1/flyer_stats?select=*`, {
      headers: {
        "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      },
    }),
    fetch(`${env.SUPABASE_URL}/rest/v1/flyer_events?kind=eq.apk_download&select=id`, {
      headers: {
        "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        "Prefer": "count=exact",
        "Range-Unit": "items",
        "Range": "0-0",
      },
    }),
  ]);
  const flyerData = await flyerRes.json();
  const apkDownloads = parseInt(apkRes.headers.get("Content-Range")?.split("/")[1] ?? "0", 10);
  return json({ ...flyerData, apk_downloads: apkDownloads }, { status: flyerRes.status }, origin);
}

// --- OpenStreetMap road obstacles ----------------------------------

const OVERPASS_URL = "https://overpass-api.de/api/interpreter";
const SPEED_BUMP_VALUES = new Set([
  "bump",
  "hump",
  "table",
  "cushion",
  "dip",
  "double_dip",
]);

function finiteNumber(value, min, max) {
  const number = Number(value);
  return Number.isFinite(number) && number >= min && number <= max
    ? number
    : null;
}

async function handleSpeedBumps(request, origin) {
  const url = new URL(request.url);
  const lat = finiteNumber(url.searchParams.get("lat"), -90, 90);
  const lng = finiteNumber(url.searchParams.get("lng"), -180, 180);
  const requestedRadius = finiteNumber(url.searchParams.get("radius_km") || "15", 1, 25);
  if (lat === null || lng === null || requestedRadius === null) {
    return json(
      { error: "invalid_coordinates", message: "lat, lng och radius_km måste vara giltiga tal." },
      { status: 400 },
      origin
    );
  }

  // Quantization lets nearby users share the same Cloudflare cache entry and
  // keeps load away from the public Overpass service.
  const cellSize = 0.05;
  const queryLat = Math.round(lat / cellSize) * cellSize;
  const queryLng = Math.round(lng / cellSize) * cellSize;
  const radiusKm = Math.ceil(requestedRadius / 5) * 5;
  const cacheKey = new Request(
    `https://cruizx-osm-cache.invalid/speed-bumps?lat=${queryLat.toFixed(2)}` +
      `&lng=${queryLng.toFixed(2)}&radius_km=${radiusKm}`
  );
  const cache = caches.default;
  const cached = await cache.match(cacheKey);
  if (cached) {
    const data = await cached.json();
    return json(data, { headers: { "Cache-Control": "public, max-age=3600", "X-CruizX-Cache": "HIT" } }, origin);
  }

  const radiusMeters = radiusKm * 1000;
  const overpassQuery = `[out:json][timeout:20];\n(` +
    `nwr(around:${radiusMeters},${queryLat},${queryLng})` +
    `["traffic_calming"~"^(bump|hump|table|cushion|dip|double_dip)$"];\n` +
    `);\nout center tags;`;

  let overpassResponse;
  try {
    overpassResponse = await fetch(OVERPASS_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
        "User-Agent": "CruizX/1.1 (https://cruizx.com)",
      },
      body: new URLSearchParams({ data: overpassQuery }),
    });
  } catch (error) {
    return json({ error: "osm_unavailable", detail: String(error) }, { status: 502 }, origin);
  }

  if (!overpassResponse.ok) {
    return json(
      { error: "osm_unavailable", status: overpassResponse.status },
      { status: 502 },
      origin
    );
  }

  const overpassData = await overpassResponse.json();
  const bumps = [];
  for (const element of overpassData.elements || []) {
    const kind = String(element.tags?.traffic_calming || "").split(";")[0];
    if (!SPEED_BUMP_VALUES.has(kind)) continue;
    const elementLat = Number(element.lat ?? element.center?.lat);
    const elementLng = Number(element.lon ?? element.center?.lon);
    if (!Number.isFinite(elementLat) || !Number.isFinite(elementLng)) continue;
    bumps.push({
      id: `osm_${element.type}_${element.id}`,
      lat: elementLat,
      lng: elementLng,
      kind,
      source: "openstreetmap",
    });
    if (bumps.length >= 2500) break;
  }

  const result = {
    source: "openstreetmap",
    center: { lat: queryLat, lng: queryLng },
    radius_km: radiusKm,
    fetched_at: new Date().toISOString(),
    count: bumps.length,
    bumps,
  };
  await cache.put(
    cacheKey,
    new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=86400" },
    })
  );
  return json(result, { headers: { "Cache-Control": "public, max-age=3600", "X-CruizX-Cache": "MISS" } }, origin);
}

// --- Entry ----------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin") || "";

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders(origin) });
    }

    if (url.pathname === "/api/download/apk" && request.method === "GET") {
      // Log download event (fire-and-forget)
      const ip = request.headers.get("CF-Connecting-IP") || "";
      const ua = request.headers.get("User-Agent") || "";
      logEvent(env, "apk_download", "website", "", ip, { ua }).catch(() => {});
      return Response.redirect(
        "https://github.com/Kimsjogren/SlowRide/releases/download/v1.1.1/CruizX-1.1.1-116-free.apk",
        302
      );
    }

    if (url.pathname === "/api/claim" && request.method === "POST") {
      return handleClaim(request, env, origin);
    }
    if (url.pathname === "/api/scan" && request.method === "POST") {
      return handleScan(request, env, origin);
    }
    if (url.pathname === "/api/stats" && request.method === "GET") {
      return handleStats(request, env, origin);
    }
    if (url.pathname === "/api/map/speed-bumps" && request.method === "GET") {
      return handleSpeedBumps(request, origin);
    }
    if (url.pathname === "/api/web/pricing" && request.method === "GET") {
      return handleWebPricing(env, origin);
    }
    if (url.pathname === "/api/web/checkout-session" && request.method === "POST") {
      return handleWebCheckoutSession(request, env, origin);
    }
    if (url.pathname === "/api/web/stripe-webhook" && request.method === "POST") {
      return handleStripeWebhook(request, env);
    }

    return json({ error: "not_found" }, { status: 404 }, origin);
  },
};
