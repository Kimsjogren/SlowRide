import SUPPORT_FAQ from "../../assets/support_faq.json" with { type: "json" };

/*
 * CruizX claim API — Cloudflare Worker
 * ---------------------------------------------------------------
 * Routes:
 *   POST /api/claim   → returnerar { code, redeem_url, repeat }
 *   POST /api/scan    → logga en QR-scan (no-op om redan loggad)
 *   GET  /api/stats   → enkel översikt (skyddad med STATS_TOKEN)
 *   GET  /api/web/pricing          → läs aktivt Stripe-pris för webb/APK
 *   GET  /api/map/speed-bumps      → cachelagrade farthinder från OpenStreetMap
 *   GET  /api/map/speed-limit      → verifierad skyltad hastighetsgräns per vägsegment
 *   GET  /api/traffic/incidents    → cachelagrad trafikinformation från Trafikverket
 *   POST /api/ai/route-analysis    → AI-sammanfattning av verifierade ruttfakta
 *   POST /api/ai/report            → rapportera ett olämpligt AI-svar
 *   POST /api/support/notify       → skicka nytt supportmeddelande till ntfy
 *   GET  /api/support/guest        → hämta en privat gästkonversation
 *   POST /api/support/guest        → skicka ett privat gästmeddelande
 *   GET  /api/support/conversation → hämta en signerad supportkonversation
 *   POST /api/support/reply        → svara i en signerad supportkonversation
 *   GET  /api/support/faq          → leverera provider-fria standardsvar
 *   POST /api/support/faq          → matcha en fråga mot standardsvaren
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
    "Access-Control-Allow-Headers": "Content-Type, Authorization, X-CruizX-Guest-Token",
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

// --- CruizX AI route analysis --------------------------------------

const AI_DAILY_LIMIT = 15;
// This model is explicitly supported by Workers AI JSON Mode. The former
// GLM model can return text, but is not one of the models supported for the
// JSON schema response required by the app.
const AI_MODEL = "@cf/meta/llama-3.1-8b-instruct-fast";
const AI_LANGUAGES = new Set(["en", "sv", "nb", "da", "fi", "fr", "es", "it"]);
const AI_VEHICLE_CONTEXT = {
  "A-tractor":
    "A speed-limited passenger-car-derived A-tractor; it is not a truck or heavy vehicle.",
  "Low vehicle":
    "A low-ground-clearance passenger car using A-tractor speed and road restrictions; avoid high speed bumps and rough or unpaved roads. It is not a truck or heavy vehicle.",
  "Moped car":
    "A light moped car (light quadricycle) with restricted road access; it is not a truck or heavy vehicle.",
  "Moped class I":
    "A two-wheeled class I moped limited to 45 km/h; avoid motorways, motor-traffic roads, cycleways, and roads without moped access. It is not a moped car or a heavy vehicle.",
  "Moped class II":
    "A two-wheeled Swedish class II moped with a construction speed of no more than 25 km/h and power no more than 1 kW. Apply the supplied country's local road-position rules. It is not an e-bike, moped car, or heavy vehicle.",
  "Electric scooter":
    "A road-legal stand-up electric scooter for one person. Apply the supplied country's exact speed, access, and public-road rules. Never describe it as a moped, motorcycle, or heavy vehicle.",
  Tractor:
    "An agricultural tractor, not a truck. No vehicle weight has been supplied.",
  Car:
    "A standard passenger car. Assess the supplied route facts without applying slow-vehicle restrictions or inventing missing road conditions.",
};
const AI_MOPED_COUNTRY_CONTEXT = {
  SE: "Sweden: moped class I may not use motorways, motor-traffic roads, or ordinary cycleways.",
  NO: "Norway: moped AM146 may not use motorways, motor-traffic roads, or ordinary cycleways; a two-wheel moped may use a bus lane unless signs restrict it.",
  DK: "Denmark: a large moped uses the roadway, not the cycleway, and may not use motorways or motor-traffic roads.",
  FI: "Finland: moped AM/120 may not use motorways or motor-traffic roads; use a cycleway only where signs explicitly allow mopeds.",
  FR: "France: a cyclomoteur may not use autoroutes or voies express; use a cycleway only where local rules explicitly permit it.",
  ES: "Spain: a ciclomotor may not use autopistas or autovías and must use a passable shoulder where required on conventional interurban roads.",
  IT: "Italy: a ciclomotore may not use autostrade, strade extraurbane principali, or cycle-only infrastructure.",
  GB: "Great Britain: a category AM moped may not use motorways. An ordinary dual carriageway is not automatically prohibited, but high-speed roads require extra caution.",
};
const AI_MOPED_II_COUNTRY_CONTEXT = {
  SE: "Sweden: a two-wheel class II moped follows bicycle traffic rules and normally uses a cycleway unless a supplementary sign prohibits mopeds.",
  NO: "Norway has no direct class-II equivalent: apply local moped rules, use the roadway, and do not use motorways, motor-traffic roads, or cycleways.",
  DK: "Denmark: treat it as a small moped; a two-wheel small moped normally must use the cycleway unless signs say otherwise.",
  FI: "Finland has no direct equivalent for every class-II design: use the conservative local moped road rules unless the vehicle is legally an L1e-A powered cycle and signs permit otherwise.",
  FR: "France has no direct class-II category: apply cyclomoteur road access, keep the 25 km/h vehicle limit, and use cycleways only where explicitly permitted.",
  ES: "Spain: apply ciclomotor rules; do not use autopistas or autovías and use a passable shoulder where required on conventional interurban roads.",
  IT: "Italy: apply ciclomotore rules; do not use autostrade, strade extraurbane principali, or cycle-only infrastructure.",
  GB: "Great Britain: treat a no-pedal vehicle limited to 25 km/h as category Q; use roads, not cycle lanes or tracks, and do not use motorways.",
};
const AI_ELECTRIC_SCOOTER_COUNTRY_CONTEXT = {
  SE: "Sweden: only a scooter limited to 20 km/h and 250 W is treated as a bicycle and allowed in public traffic; use bicycle infrastructure and never the pavement.",
  NO: "Norway: maximum 20 km/h; cycle lanes, shared paths and roads are allowed, while pavement use is only considerate and at walking speed around pedestrians.",
  DK: "Denmark: maximum 20 km/h and bicycle rules apply; use the cycleway when one is present.",
  FI: "Finland: a light electric vehicle may be at most 25 km/h and 1 kW and follows bicycle traffic rules, normally using the cycle path.",
  FR: "France: an EDPM is limited to 25 km/h and must use cycle lanes or tracks when present; outside built-up areas use greenways or cycleways unless local authorities expressly allow a road.",
  ES: "Spain: a VMP is limited to 6–25 km/h and may use only locally authorised urban roads; pavements, pedestrian zones, crossings, interurban roads, motorways, expressways, and urban tunnels are prohibited.",
  IT: "Italy: an electric scooter is limited to 20 km/h, or 6 km/h in pedestrian areas; use authorised urban roads up to 50 km/h and permitted cycle infrastructure, and follow current identification and insurance requirements.",
  GB: "Great Britain: private e-scooters are illegal on public roads and public spaces. Only an approved rental-trial scooter may use authorised roads and cycle lanes in a trial area; pavements and motorways are prohibited.",
};
const AI_REPORT_REASONS = new Set([
  "incorrect",
  "unsafe",
  "inappropriate",
  "other",
]);

async function authenticatedUser(request, env) {
  const authorization = request.headers.get("Authorization") || "";
  if (!authorization.startsWith("Bearer ")) return null;
  const response = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: authorization,
    },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return isUuid(user?.id) ? user : null;
}

function aiFiniteNumber(value, min, max) {
  return typeof value === "number" && Number.isFinite(value) && value >= min && value <= max;
}

function cleanStrings(value, maxItems, maxLength) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item) => typeof item === "string")
    .map((item) => item.replace(/\s+/g, " ").trim().slice(0, maxLength))
    .filter(Boolean)
    .slice(0, maxItems);
}

function validateAiRouteFacts(body) {
  if (!body || typeof body !== "object" || !AI_LANGUAGES.has(body.language)) return null;
  if (
    typeof body.vehicle_type !== "string" ||
    !Object.hasOwn(AI_VEHICLE_CONTEXT, body.vehicle_type)
  ) return null;
  if (typeof body.country_code !== "string" || !/^[A-Z]{2}$/.test(body.country_code)) return null;
  if (!aiFiniteNumber(body.max_speed_kmh, 5, 130)) return null;
  const route = body.route;
  if (!route || typeof route !== "object") return null;
  if (!aiFiniteNumber(route.distance_km, 0.1, 2000)) return null;
  if (!aiFiniteNumber(route.duration_minutes, 1, 3000)) return null;

  const alertCounts = {};
  if (body.alert_counts && typeof body.alert_counts === "object") {
    for (const [key, value] of Object.entries(body.alert_counts).slice(0, 20)) {
      if (/^[a-z_]{1,32}$/.test(key) && Number.isInteger(value) && value >= 0 && value <= 500) {
        alertCounts[key] = value;
      }
    }
  }
  return {
    language: body.language,
    vehicle_type: body.vehicle_type,
    vehicle_context:
      AI_VEHICLE_CONTEXT[body.vehicle_type] +
      (body.vehicle_type === "Moped class I"
        ? ` ${AI_MOPED_COUNTRY_CONTEXT[body.country_code] || AI_MOPED_COUNTRY_CONTEXT.SE}`
        : body.vehicle_type === "Moped class II"
          ? ` ${AI_MOPED_II_COUNTRY_CONTEXT[body.country_code] || AI_MOPED_II_COUNTRY_CONTEXT.SE}`
          : body.vehicle_type === "Electric scooter"
            ? ` ${AI_ELECTRIC_SCOOTER_COUNTRY_CONTEXT[body.country_code] || AI_ELECTRIC_SCOOTER_COUNTRY_CONTEXT.SE}`
          : ""),
    country_code: body.country_code,
    max_speed_kmh: body.max_speed_kmh,
    route: {
      distance_km: body.route.distance_km,
      duration_minutes: body.route.duration_minutes,
      street_names: cleanStrings(body.route.street_names, 24, 80),
    },
    alert_counts: alertCounts,
  };
}

async function aiUsageToday(env, userHash) {
  const since = new Date();
  since.setUTCHours(0, 0, 0, 0);
  const url =
    `${env.SUPABASE_URL}/rest/v1/flyer_events?kind=eq.ai_route_analysis` +
    `&device_hash=eq.${encodeURIComponent(userHash)}` +
    `&created_at=gte.${encodeURIComponent(since.toISOString())}&select=id&limit=${AI_DAILY_LIMIT}`;
  const response = await fetch(url, {
    headers: {
      apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
    },
  });
  if (!response.ok) return AI_DAILY_LIMIT;
  const rows = await response.json();
  return Array.isArray(rows) ? rows.length : AI_DAILY_LIMIT;
}

const AI_ROUTE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    headline: { type: "string", maxLength: 80 },
    summary: { type: "string", maxLength: 280 },
    suitability: { type: "string", enum: ["good", "caution", "not_recommended"] },
    highlights: {
      type: "array",
      maxItems: 3,
      items: { type: "string", maxLength: 110 },
    },
    cautions: {
      type: "array",
      maxItems: 3,
      items: { type: "string", maxLength: 110 },
    },
    recommendation: { type: "string", maxLength: 160 },
  },
  required: [
    "headline",
    "summary",
    "suitability",
    "highlights",
    "cautions",
    "recommendation",
  ],
};

function validateAiAnalysis(value) {
  if (!value || typeof value !== "object") return null;
  const stringField = (key, maxLength) => {
    const text = value[key];
    return typeof text === "string" && text.trim()
      ? text.replace(/\s+/g, " ").trim().slice(0, maxLength)
      : null;
  };
  const stringList = (key) => {
    if (!Array.isArray(value[key]) || value[key].length > 3) return null;
    const items = cleanStrings(value[key], 3, 110);
    return items.length === value[key].length ? items : null;
  };
  const headline = stringField("headline", 80);
  const summary = stringField("summary", 280);
  const recommendation = stringField("recommendation", 160);
  const highlights = stringList("highlights");
  const cautions = stringList("cautions");
  const suitability = value.suitability;
  if (
    !headline ||
    !summary ||
    !recommendation ||
    !highlights ||
    !cautions ||
    !["good", "caution", "not_recommended"].includes(suitability)
  ) {
    return null;
  }
  return {
    headline,
    summary,
    suitability,
    highlights,
    cautions,
    recommendation,
  };
}

async function handleAiRouteAnalysis(request, env, origin) {
  if (!env.AI) {
    return json({ error: "ai_not_configured" }, { status: 503 }, origin);
  }
  const user = await authenticatedUser(request, env);
  if (!user) return json({ error: "sign_in_required" }, { status: 401 }, origin);

  const contentLength = Number(request.headers.get("Content-Length") || 0);
  if (contentLength > 20_000) {
    return json({ error: "request_too_large" }, { status: 413 }, origin);
  }
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, { status: 400 }, origin);
  }
  const facts = validateAiRouteFacts(body);
  if (!facts) return json({ error: "invalid_route_facts" }, { status: 400 }, origin);

  const userHash = await sha256Hex(`${env.DEVICE_SALT}|ai|${user.id}`);
  const usage = await aiUsageToday(env, userHash);
  if (usage >= AI_DAILY_LIMIT) {
    return json({ error: "daily_limit", limit: AI_DAILY_LIMIT }, { status: 429 }, origin);
  }

  try {
    const aiResult = await env.AI.run(AI_MODEL, {
      messages: [
        {
          role: "system",
          content:
            "You are CruizX AI route analysis. Analyze only the supplied, already-computed route facts. " +
            "Never invent roads, restrictions, incidents, weather, police locations, legal guarantees, or missing data. " +
            "Do not create or modify a route and do not tell the driver to interact with the app while driving. " +
            "Use the supplied vehicle_context as the exact vehicle classification. Never infer vehicle weight, " +
            "and never call the selected vehicle a heavy vehicle or truck. " +
            "Be concise and practical for the supplied slow-vehicle type. Use one short summary sentence, " +
            "at most three short highlights, at most three short cautions, and one short recommendation. " +
            "Treat community alerts as unverified. " +
            `Write every output string in language code ${facts.language}.`,
        },
        { role: "user", content: JSON.stringify(facts) },
      ],
      response_format: {
        type: "json_schema",
        json_schema: AI_ROUTE_SCHEMA,
      },
      max_completion_tokens: 360,
      chat_template_kwargs: { enable_thinking: false },
      store: false,
      temperature: 0.2,
    });
    const responseContent =
      aiResult?.response ?? aiResult?.choices?.[0]?.message?.content;
    const rawAnalysis =
      typeof responseContent === "string"
        ? JSON.parse(responseContent)
        : responseContent;
    const analysis = validateAiAnalysis(rawAnalysis);
    if (!analysis) {
      return json({ error: "ai_invalid_response" }, { status: 502 }, origin);
    }

    const responseId = crypto.randomUUID();
    const ip = request.headers.get("CF-Connecting-IP") || "";
    await logEvent(env, "ai_route_analysis", "app", userHash, ip, {
      response_id: responseId,
      model: AI_MODEL,
      country_code: facts.country_code,
      vehicle_type: facts.vehicle_type,
      input_tokens: aiResult?.usage?.prompt_tokens ?? null,
      output_tokens: aiResult?.usage?.completion_tokens ?? null,
    });
    return json({ response_id: responseId, ...analysis }, {
      headers: { "Cache-Control": "no-store" },
    }, origin);
  } catch (error) {
    const message = String(error?.message || error);
    console.error("Workers AI route analysis failed", message);
    if (message.includes("3036") || message.includes("429")) {
      return json({ error: "daily_limit" }, { status: 429 }, origin);
    }
    return json({ error: "ai_invalid_response" }, { status: 502 }, origin);
  }
}

async function handleAiReport(request, env, origin) {
  const user = await authenticatedUser(request, env);
  if (!user) return json({ error: "sign_in_required" }, { status: 401 }, origin);
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, { status: 400 }, origin);
  }
  if (
    typeof body?.response_id !== "string" ||
    body.response_id.length > 100 ||
    !AI_REPORT_REASONS.has(body.reason)
  ) {
    return json({ error: "invalid_report" }, { status: 400 }, origin);
  }
  const userHash = await sha256Hex(`${env.DEVICE_SALT}|ai|${user.id}`);
  const ip = request.headers.get("CF-Connecting-IP") || "";
  await logEvent(env, "ai_response_report", "app", userHash, ip, {
    response_id: body.response_id,
    reason: body.reason,
  });
  return json({ ok: true }, { headers: { "Cache-Control": "no-store" } }, origin);
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

// --- Support inbox + ntfy ------------------------------------------

const SUPPORT_REPLY_LIFETIME_SECONDS = 7 * 24 * 60 * 60;

function normalizeNtfyTopic(rawTopic) {
  let topic = String(rawTopic || "").trim();
  topic = topic.replace(/^NTFY_TOPIC\s*=\s*/i, "").trim();
  topic = topic.replace(/^(["'])(.*)\1$/, "$2").trim();

  try {
    const url = new URL(topic);
    topic = url.pathname.split("/").findLast(Boolean) || "";
  } catch (_) {
    if (topic.includes("/")) {
      topic = topic.split("/").findLast(Boolean) || "";
    }
  }

  return topic;
}

async function supportReplySignature(env, userId, expires) {
  return hmacSha256Hex(env.SUPPORT_REPLY_SECRET, `${userId}.${expires}`);
}

async function validateSupportReplyAccess(url, env) {
  if (!env.SUPPORT_REPLY_SECRET) return null;
  const userId = (url.searchParams.get("user") || "").trim();
  const guestHash = (url.searchParams.get("guest") || "").trim().toLowerCase();
  const expires = Number(url.searchParams.get("expires"));
  const signature = (url.searchParams.get("signature") || "").trim().toLowerCase();
  const now = Math.floor(Date.now() / 1000);
  if (
    (isUuid(userId) === /^[a-f0-9]{64}$/.test(guestHash)) ||
    !Number.isInteger(expires) ||
    expires < now ||
    expires > now + SUPPORT_REPLY_LIFETIME_SECONDS + 300 ||
    !/^[a-f0-9]{64}$/.test(signature)
  ) {
    return null;
  }
  const identity = userId || `guest:${guestHash}`;
  const expected = await supportReplySignature(env, identity, expires);
  return constantTimeEqual(signature, expected)
    ? { userId: userId || null, guestHash: guestHash || null, expires }
    : null;
}

function supportSupabaseHeaders(env, extra = {}) {
  return {
    "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
    "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
    ...extra,
  };
}

async function loadSupportUser(env, userId) {
  const response = await fetch(
    `${env.SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
    { headers: supportSupabaseHeaders(env) }
  );
  if (!response.ok) return { id: userId, email: "" };
  const user = await response.json();
  return {
    id: userId,
    email: typeof user?.email === "string" ? user.email : "",
  };
}

async function handleSupportNotify(request, env) {
  if (
    !env.SUPPORT_WEBHOOK_SECRET ||
    !env.SUPPORT_REPLY_SECRET ||
    !env.NTFY_SERVER_URL ||
    !env.NTFY_TOPIC
  ) {
    return new Response("support notifications not configured", { status: 503 });
  }

  const suppliedSecret = request.headers.get("X-CruizX-Webhook-Secret") || "";
  if (!constantTimeEqual(suppliedSecret, env.SUPPORT_WEBHOOK_SECRET)) {
    return new Response("unauthorized", { status: 401 });
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return new Response("invalid json", { status: 400 });
  }

  const record = payload?.record;
  const hasUser = isUuid(record?.user_id);
  const hasGuest = /^[a-f0-9]{64}$/.test(String(record?.guest_token_hash || ""));
  if (
    !record ||
    hasUser === hasGuest ||
    record.sender !== "user" ||
    typeof record.body !== "string" ||
    !record.body.trim()
  ) {
    return new Response("ignored", { status: 202 });
  }

  const user = hasUser
    ? await loadSupportUser(env, record.user_id)
    : { id: `guest:${record.guest_token_hash.slice(0, 10)}`, email: "Gäst i CruizX" };
  const expires = Math.floor(Date.now() / 1000) + SUPPORT_REPLY_LIFETIME_SECONDS;
  const identity = hasUser ? record.user_id : `guest:${record.guest_token_hash}`;
  const signature = await supportReplySignature(env, identity, expires);
  const replyUrl = new URL("https://cruizx.com/support-reply.html");
  if (hasUser) replyUrl.searchParams.set("user", record.user_id);
  else replyUrl.searchParams.set("guest", record.guest_token_hash);
  replyUrl.searchParams.set("expires", String(expires));
  replyUrl.searchParams.set("signature", signature);

  const ntfyBase = env.NTFY_SERVER_URL.replace(/\/+$/, "");
  const ntfyTopic = normalizeNtfyTopic(env.NTFY_TOPIC);
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(ntfyTopic)) {
    console.error("ntfy support notification topic is invalid", {
      length: ntfyTopic.length,
    });
    return new Response("ntfy topic invalid", { status: 503 });
  }
  const ntfyPayload = {
    topic: ntfyTopic,
    title: "Nytt supportmeddelande i CruizX",
    message: `${user.email || "Okänd användare"}\n\n${record.body.trim().slice(0, 2000)}`,
    priority: 4,
    tags: ["speech_balloon"],
    click: replyUrl.toString(),
    actions: [
      {
        action: "view",
        label: "Svara",
        url: replyUrl.toString(),
        clear: true,
      },
    ],
  };
  const headers = { "Content-Type": "application/json" };
  if (env.NTFY_ACCESS_TOKEN) {
    headers.Authorization = `Bearer ${env.NTFY_ACCESS_TOKEN}`;
  }
  const ntfyResponse = await fetch(ntfyBase, {
    method: "POST",
    headers,
    body: JSON.stringify(ntfyPayload),
  });
  if (!ntfyResponse.ok) {
    const ntfyError = (await ntfyResponse.text()).slice(0, 1000);
    console.error("ntfy support notification failed", {
      status: ntfyResponse.status,
      error: ntfyError,
    });
    const fallbackResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/rpc/publish_support_ntfy`,
      {
        method: "POST",
        headers: supportSupabaseHeaders(env, { "Content-Type": "application/json" }),
        body: JSON.stringify({ p_payload: ntfyPayload }),
      }
    );
    if (fallbackResponse.ok) {
      return new Response("ok (fallback queued)", { status: 200 });
    }
    return new Response(`ntfy failed: ${ntfyResponse.status}`, { status: 502 });
  }
  return new Response("ok", { status: 200 });
}

async function handleGuestSupport(request, env, origin) {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) {
    return json({ error: "support_not_configured" }, { status: 503 }, origin);
  }

  const guestToken = (
    request.headers.get("X-CruizX-Guest-Token") || ""
  ).trim();
  if (!/^[A-Za-z0-9_-]{43,128}$/.test(guestToken)) {
    return json({ error: "invalid_guest_token" }, { status: 401 }, origin);
  }
  const guestHash = await sha256Hex(guestToken);

  if (request.method === "GET") {
    const ownerFilter = `guest_token_hash=eq.${guestHash}`;
    const messagesResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/support_messages` +
        `?select=id,user_id,sender,body,language_code,created_at,read_at` +
        `&${ownerFilter}&order=created_at.asc&limit=500`,
      { headers: supportSupabaseHeaders(env) }
    );
    if (!messagesResponse.ok) {
      return json({ error: "conversation_unavailable" }, { status: 502 }, origin);
    }
    const messages = await messagesResponse.json();

    const readResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/support_messages` +
        `?${ownerFilter}&sender=eq.support&read_at=is.null`,
      {
        method: "PATCH",
        headers: supportSupabaseHeaders(env, {
          "Content-Type": "application/json",
          "Prefer": "return=minimal",
        }),
        body: JSON.stringify({ read_at: new Date().toISOString() }),
      }
    );
    if (!readResponse.ok) {
      console.error("guest support read receipt failed", {
        status: readResponse.status,
      });
    }

    return json(
      { status: "ok", messages: Array.isArray(messages) ? messages : [] },
      { status: 200, headers: { "Cache-Control": "no-store" } },
      origin
    );
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid_json" }, { status: 400 }, origin);
  }
  const body = typeof payload?.body === "string" ? payload.body.trim() : "";
  if (!body || body.length > 2000) {
    return json({ error: "invalid_message" }, { status: 400 }, origin);
  }
  const supportedLanguages = new Set(["sv", "en", "da", "nb", "fi", "fr", "es", "it"]);
  const requestedLanguage = String(payload?.language_code || "en").toLowerCase();
  const languageCode = supportedLanguages.has(requestedLanguage)
    ? requestedLanguage
    : "en";

  const insertResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/rpc/insert_guest_support_message`,
    {
      method: "POST",
      headers: supportSupabaseHeaders(env, {
        "Content-Type": "application/json",
      }),
      body: JSON.stringify({
        p_guest_token_hash: guestHash,
        p_body: body,
        p_language_code: languageCode,
      }),
    }
  );
  if (!insertResponse.ok) {
    const status = insertResponse.status === 429 ? 429 : 502;
    return json({ error: "message_failed" }, { status }, origin);
  }
  const inserted = await insertResponse.json();
  const message = Array.isArray(inserted) ? inserted[0] : inserted;
  return json(
    { status: "ok", message: message || null },
    { status: 201, headers: { "Cache-Control": "no-store" } },
    origin
  );
}

function normalizeSupportFaqText(value) {
  const replacements = {
    å: "a", ä: "a", ö: "o", æ: "a", ø: "o", é: "e", è: "e",
    ê: "e", à: "a", á: "a", í: "i", ì: "i", ó: "o", ò: "o",
    ú: "u", ù: "u",
  };
  return String(value || "")
    .toLowerCase()
    .replace(/[åäöæøéèêàáíìóòúù]/g, (letter) => replacements[letter] || letter)
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function matchSupportFaq(question, languageCode) {
  const normalizedQuestion = normalizeSupportFaqText(question);
  if (!normalizedQuestion) return null;
  let best = null;
  let bestScore = 0;
  for (const entry of SUPPORT_FAQ.entries || []) {
    const localizedQuestion = entry.question?.[languageCode] || entry.question?.en || "";
    let score = normalizedQuestion === normalizeSupportFaqText(localizedQuestion) ? 100 : 0;
    const triggers = new Set([
      ...(entry.triggers?.[languageCode] || []),
      ...(entry.triggers?.en || []),
    ]);
    for (const trigger of triggers) {
      const normalizedTrigger = normalizeSupportFaqText(trigger);
      if (normalizedTrigger && normalizedQuestion.includes(normalizedTrigger)) {
        score = Math.max(score, 20 + normalizedTrigger.split(" ").length);
      }
    }
    if (score > bestScore) {
      best = entry;
      bestScore = score;
    }
  }
  return bestScore >= 20 ? best : null;
}

async function handleSupportFaq(request, origin) {
  if (request.method === "GET") {
    return json(SUPPORT_FAQ, {
      headers: { "Cache-Control": "public, max-age=3600" },
    }, origin);
  }
  const contentLength = Number(request.headers.get("Content-Length") || 0);
  if (contentLength > 4_000) {
    return json({ error: "request_too_large" }, { status: 413 }, origin);
  }
  let payload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid_json" }, { status: 400 }, origin);
  }
  const question = typeof payload?.question === "string" ? payload.question.trim() : "";
  if (!question || question.length > 2000) {
    return json({ error: "invalid_question" }, { status: 400 }, origin);
  }
  const supportedLanguages = new Set(["sv", "en", "da", "nb", "fi", "fr", "es", "it"]);
  const requestedLanguage = String(payload?.language_code || "en").toLowerCase();
  const languageCode = supportedLanguages.has(requestedLanguage) ? requestedLanguage : "en";
  const entry = matchSupportFaq(question, languageCode);
  return json({
    matched: Boolean(entry),
    entry: entry
      ? {
          id: entry.id,
          question: entry.question?.[languageCode] || entry.question?.en || "",
          answer: entry.answer?.[languageCode] || entry.answer?.en || "",
        }
      : null,
  }, { headers: { "Cache-Control": "no-store" } }, origin);
}

async function handleSupportConversation(request, env, origin) {
  const url = new URL(request.url);
  const access = await validateSupportReplyAccess(url, env);
  if (!access) {
    return json({ error: "invalid_or_expired_link" }, { status: 401 }, origin);
  }

  const ownerFilter = access.userId
    ? `user_id=eq.${encodeURIComponent(access.userId)}`
    : `guest_token_hash=eq.${access.guestHash}`;
  const messagesUrl =
    `${env.SUPABASE_URL}/rest/v1/support_messages` +
    `?select=id,sender,body,language_code,created_at,read_at` +
    `&${ownerFilter}` +
    `&order=created_at.asc&limit=500`;
  const [messagesResponse, user] = await Promise.all([
    fetch(messagesUrl, { headers: supportSupabaseHeaders(env) }),
    access.userId
      ? loadSupportUser(env, access.userId)
      : Promise.resolve({ id: `guest:${access.guestHash.slice(0, 10)}`, email: "Gäst i CruizX" }),
  ]);
  if (!messagesResponse.ok) {
    return json({ error: "conversation_unavailable" }, { status: 502 }, origin);
  }

  const messages = await messagesResponse.json();
  fetch(
    `${env.SUPABASE_URL}/rest/v1/support_messages` +
      `?${ownerFilter}&sender=eq.user&read_at=is.null`,
    {
      method: "PATCH",
      headers: supportSupabaseHeaders(env, {
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
      }),
      body: JSON.stringify({ read_at: new Date().toISOString() }),
    }
  ).catch(() => {});

  return json(
    { status: "ok", user, messages: Array.isArray(messages) ? messages : [] },
    { status: 200, headers: { "Cache-Control": "no-store" } },
    origin
  );
}

async function handleSupportReply(request, env, origin) {
  const url = new URL(request.url);
  const access = await validateSupportReplyAccess(url, env);
  if (!access) {
    return json({ error: "invalid_or_expired_link" }, { status: 401 }, origin);
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid_json" }, { status: 400 }, origin);
  }
  const body = typeof payload?.body === "string" ? payload.body.trim() : "";
  if (!body || body.length > 2000) {
    return json({ error: "invalid_message" }, { status: 400 }, origin);
  }

  const insertResponse = await fetch(`${env.SUPABASE_URL}/rest/v1/support_messages`, {
    method: "POST",
    headers: supportSupabaseHeaders(env, {
      "Content-Type": "application/json",
      "Prefer": "return=representation",
    }),
    body: JSON.stringify({
      ...(access.userId
        ? { user_id: access.userId }
        : { guest_token_hash: access.guestHash }),
      sender: "support",
      body,
      language_code: "sv",
    }),
  });
  if (!insertResponse.ok) {
    return json({ error: "reply_failed" }, { status: 502 }, origin);
  }
  const rows = await insertResponse.json();
  return json(
    { status: "ok", message: Array.isArray(rows) ? rows[0] : null },
    { status: 201, headers: { "Cache-Control": "no-store" } },
    origin
  );
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

// --- Verified road speed limits ------------------------------------

const SPEED_LIMIT_COUNTRIES = new Set(["SE", "NO", "DK", "FI", "FR", "ES"]);
const TRAFIKVERKET_SPEED_LIMIT_URL =
  "https://vektor.trafikverket.se/gis/rest/services/TVTF/Trafikverkets_hastighetsgr%C3%A4nser/MapServer/0/query";
const DGT_SPEED_LIMIT_URL = "https://infocar.dgt.es/tnits/limitesVelocidad.xml";
const DGT_INDEX_CACHE_KEY = new Request("https://cruizx-speed-limit-cache.invalid/dgt-es-index-v2");
const FINTRAFFIC_SPEED_LIMIT_URL =
  "https://avoinapi.vaylapilvi.fi/vaylatiedot/digiroad/ogc/features/v1/collections/dr_nopeusrajoitus/items";
const NORWAY_NVDB_SPEED_LIMIT_URL =
  "https://nvdbapiles.atlas.vegvesen.no/vegobjekter/api/v4/vegobjekter/105";

function degreesToRadians(value) {
  return (value * Math.PI) / 180;
}

function roadDistanceMeters(point, start, end) {
  const earthRadius = 6371000;
  const latitude = degreesToRadians(point.lat);
  const toXY = (coordinate) => ({
    x: earthRadius * degreesToRadians(coordinate.lng - point.lng) * Math.cos(latitude),
    y: earthRadius * degreesToRadians(coordinate.lat - point.lat),
  });
  const a = toXY(start);
  const b = toXY(end);
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const lengthSquared = dx * dx + dy * dy;
  if (lengthSquared === 0) return Math.hypot(a.x, a.y);
  const t = Math.max(0, Math.min(1, -(a.x * dx + a.y * dy) / lengthSquared));
  return Math.hypot(a.x + t * dx, a.y + t * dy);
}

function roadBearingDegrees(start, end) {
  const deltaLng = degreesToRadians(end.lng - start.lng);
  const startLat = degreesToRadians(start.lat);
  const endLat = degreesToRadians(end.lat);
  const y = Math.sin(deltaLng) * Math.cos(endLat);
  const x =
    Math.cos(startLat) * Math.sin(endLat) -
    Math.sin(startLat) * Math.cos(endLat) * Math.cos(deltaLng);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

function angularDifferenceDegrees(a, b) {
  return Math.abs(((a - b + 540) % 360) - 180);
}

// Norwegian NVDB uses ETRS89 / UTM zone 33N (EPSG:5973) for geometry and
// map windows. The formulas keep the Worker dependency-free and let us fetch
// only a small area around the current location.
function wgs84ToUtm33(lat, lng) {
  const a = 6378137;
  const eccentricitySquared = 0.00669437999014;
  const eccentricityPrimeSquared = eccentricitySquared / (1 - eccentricitySquared);
  const k0 = 0.9996;
  const latitude = degreesToRadians(lat);
  const longitudeDelta = degreesToRadians(lng - 15);
  const sinLatitude = Math.sin(latitude);
  const cosLatitude = Math.cos(latitude);
  const tangentSquared = Math.tan(latitude) ** 2;
  const n = a / Math.sqrt(1 - eccentricitySquared * sinLatitude * sinLatitude);
  const c = eccentricityPrimeSquared * cosLatitude * cosLatitude;
  const arc = cosLatitude * longitudeDelta;
  const meridionalArc =
    a *
    ((1 - eccentricitySquared / 4 - (3 * eccentricitySquared ** 2) / 64 - (5 * eccentricitySquared ** 3) / 256) *
      latitude -
      ((3 * eccentricitySquared) / 8 + (3 * eccentricitySquared ** 2) / 32 +
        (45 * eccentricitySquared ** 3) / 1024) *
        Math.sin(2 * latitude) +
      ((15 * eccentricitySquared ** 2) / 256 + (45 * eccentricitySquared ** 3) / 1024) *
        Math.sin(4 * latitude) -
      ((35 * eccentricitySquared ** 3) / 3072) * Math.sin(6 * latitude));
  return {
    easting:
      k0 *
        n *
        (arc +
          ((1 - tangentSquared + c) * arc ** 3) / 6 +
          ((5 - 18 * tangentSquared + tangentSquared ** 2 + 72 * c - 58 * eccentricityPrimeSquared) *
            arc ** 5) /
            120) +
      500000,
    northing:
      k0 *
      (meridionalArc +
        n *
          Math.tan(latitude) *
          (arc ** 2 / 2 +
            ((5 - tangentSquared + 9 * c + 4 * c ** 2) * arc ** 4) / 24 +
            ((61 - 58 * tangentSquared + tangentSquared ** 2 + 600 * c - 330 * eccentricityPrimeSquared) *
              arc ** 6) /
              720)),
  };
}

function utm33ToWgs84(easting, northing) {
  // Reuse the thoroughly bounded inverse used for the DGT feed, with the
  // Norwegian UTM zone's central meridian (15°E).
  const a = 6378137;
  const eccentricitySquared = 0.00669437999014;
  const eccentricityPrimeSquared = eccentricitySquared / (1 - eccentricitySquared);
  const k0 = 0.9996;
  const x = easting - 500000;
  const meridionalArc = northing / k0;
  const mu =
    meridionalArc /
    (a *
      (1 -
        eccentricitySquared / 4 -
        (3 * eccentricitySquared * eccentricitySquared) / 64 -
        (5 * eccentricitySquared * eccentricitySquared * eccentricitySquared) / 256));
  const e1 = (1 - Math.sqrt(1 - eccentricitySquared)) / (1 + Math.sqrt(1 - eccentricitySquared));
  const phi1 =
    mu +
    ((3 * e1) / 2 - (27 * e1 ** 3) / 32) * Math.sin(2 * mu) +
    ((21 * e1 * e1) / 16 - (55 * e1 ** 4) / 32) * Math.sin(4 * mu) +
    ((151 * e1 ** 3) / 96) * Math.sin(6 * mu);
  const sinPhi1 = Math.sin(phi1);
  const cosPhi1 = Math.cos(phi1);
  const tanPhi1 = Math.tan(phi1);
  const n1 = a / Math.sqrt(1 - eccentricitySquared * sinPhi1 * sinPhi1);
  const t1 = tanPhi1 * tanPhi1;
  const c1 = eccentricityPrimeSquared * cosPhi1 * cosPhi1;
  const r1 =
    (a * (1 - eccentricitySquared)) /
    (1 - eccentricitySquared * sinPhi1 * sinPhi1) ** 1.5;
  const d = x / (n1 * k0);
  const latitude =
    phi1 -
    ((n1 * tanPhi1) / r1) *
      (d * d / 2 -
        ((5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * eccentricityPrimeSquared) * d ** 4) / 24 +
        ((61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * eccentricityPrimeSquared - 3 * c1 * c1) *
          d ** 6) /
          720);
  const longitude =
    ((d - ((1 + 2 * t1 + c1) * d ** 3) / 6 +
      ((5 - 2 * t1 + 28 * t1 - 3 * c1 * c1 + 8 * eccentricityPrimeSquared + 24 * t1 * t1) *
        d ** 5) /
        120) /
      cosPhi1) +
    degreesToRadians(15);
  return { lat: (latitude * 180) / Math.PI, lng: (longitude * 180) / Math.PI };
}

function parseNvdbWktLineString(wkt) {
  if (typeof wkt !== "string") return [];
  const match = /LINESTRING(?:\s+Z)?\s*\(([^)]+)\)/i.exec(wkt);
  if (!match) return [];
  return match[1]
    .split(",")
    .map((raw) => raw.trim().split(/\s+/).map(Number))
    .filter((coordinate) => Number.isFinite(coordinate[0]) && Number.isFinite(coordinate[1]))
    .map(([easting, northing]) => utm33ToWgs84(easting, northing));
}

// Every official line source goes through this matcher. A legal speed is
// returned only when GPS, the route's snapped position, and travel heading all
// agree on the same road segment. This prevents a parallel motorway or ramp
// from leaking its limit into the current road.
function matchOfficialSpeedSegments(query, segments, { country, source }) {
  const candidates = [];
  for (const segment of segments) {
    const { limit, start, end } = segment;
    if (!Number.isFinite(limit) || limit < 5 || limit > 200) continue;
    if (![start?.lng, start?.lat, end?.lng, end?.lat].every(Number.isFinite)) continue;
    const segmentBearing = roadBearingDegrees(start, end);
    const alignment = Math.min(
      angularDifferenceDegrees(segmentBearing, query.heading),
      angularDifferenceDegrees((segmentBearing + 180) % 360, query.heading)
    );
    const distance = roadDistanceMeters(query.position, start, end);
    const routeDistance = roadDistanceMeters(query.routePosition, start, end);
    // Do not trade correctness for coverage. A sign is shown only when both
    // the GPS fix and the active route agree on a very close, same-direction
    // official road segment. Returning unknown is safer than a parallel 110.
    if (distance > 14 || routeDistance > 18 || alignment > 52) continue;
    candidates.push({ limit, distance, routeDistance, alignment });
  }
  if (!candidates.length) return speedLimitResponse({ country, source, status: "unknown" });
  const score = (candidate) =>
    candidate.routeDistance * 3 + candidate.distance * 1.5 + candidate.alignment * 0.45;
  candidates.sort((a, b) => score(a) - score(b));
  const best = candidates[0];
  const runnerUp = candidates[1];
  if (runnerUp && best.limit !== runnerUp.limit && score(runnerUp) - score(best) < 16) {
    return speedLimitResponse({ country, source, status: "ambiguous" });
  }
  return speedLimitResponse({
    country,
    limitKmh: best.limit,
    source,
    status: "verified",
    confidence: "high",
  });
}

function parseSpeedLimitQuery(request) {
  const url = new URL(request.url);
  const lat = finiteNumber(url.searchParams.get("lat"), -90, 90);
  const lng = finiteNumber(url.searchParams.get("lng"), -180, 180);
  const heading = finiteNumber(url.searchParams.get("heading"), 0, 359.999);
  const country = String(url.searchParams.get("country") || "").trim().toUpperCase();
  const rawRouteLat = url.searchParams.get("route_lat");
  const rawRouteLng = url.searchParams.get("route_lng");
  const routeLat = rawRouteLat === null ? null : finiteNumber(rawRouteLat, -90, 90);
  const routeLng = rawRouteLng === null ? null : finiteNumber(rawRouteLng, -180, 180);
  if (lat === null || lng === null || heading === null || !SPEED_LIMIT_COUNTRIES.has(country)) {
    return null;
  }
  if ((routeLat === null) !== (routeLng === null)) return null;
  return {
    position: { lat, lng },
    heading,
    country,
    routePosition: routeLat === null ? { lat, lng } : { lat: routeLat, lng: routeLng },
  };
}

function speedLimitResponse({ country, limitKmh = null, source, status, confidence = "none" }) {
  return {
    country,
    limit_kmh: limitKmh,
    source,
    status,
    confidence,
    checked_at: new Date().toISOString(),
  };
}

function speedLimitCacheRequest(query) {
  // A 30 road can run only a few metres from a motorway. Keep cache cells
  // smaller than a road carriageway and do not reuse a result for a broadly
  // different direction.
  const headingBucket = Math.round(query.heading / 10) * 10;
  return new Request(
    "https://cruizx-speed-limit-cache.invalid/limit?" +
      new URLSearchParams({
        country: query.country,
        lat: query.position.lat.toFixed(5),
        lng: query.position.lng.toFixed(5),
        route_lat: query.routePosition.lat.toFixed(5),
        route_lng: query.routePosition.lng.toFixed(5),
        heading: String(headingBucket),
      })
  );
}

// DGT publishes its national-road R-301 signs in ETRS89 / UTM zone 30N,
// represented as northing,easting in the ROSATTE XML posList field.
function dgtUtm30ToWgs84(northing, easting) {
  const a = 6378137;
  const eccentricitySquared = 0.00669437999014;
  const eccentricityPrimeSquared = eccentricitySquared / (1 - eccentricitySquared);
  const k0 = 0.9996;
  const x = easting - 500000;
  const y = northing;
  const meridionalArc = y / k0;
  const mu =
    meridionalArc /
    (a *
      (1 -
        eccentricitySquared / 4 -
        (3 * eccentricitySquared * eccentricitySquared) / 64 -
        (5 * eccentricitySquared * eccentricitySquared * eccentricitySquared) / 256));
  const e1 = (1 - Math.sqrt(1 - eccentricitySquared)) / (1 + Math.sqrt(1 - eccentricitySquared));
  const phi1 =
    mu +
    ((3 * e1) / 2 - (27 * e1 ** 3) / 32) * Math.sin(2 * mu) +
    ((21 * e1 * e1) / 16 - (55 * e1 ** 4) / 32) * Math.sin(4 * mu) +
    ((151 * e1 ** 3) / 96) * Math.sin(6 * mu);
  const sinPhi1 = Math.sin(phi1);
  const cosPhi1 = Math.cos(phi1);
  const tanPhi1 = Math.tan(phi1);
  const n1 = a / Math.sqrt(1 - eccentricitySquared * sinPhi1 * sinPhi1);
  const t1 = tanPhi1 * tanPhi1;
  const c1 = eccentricityPrimeSquared * cosPhi1 * cosPhi1;
  const r1 =
    (a * (1 - eccentricitySquared)) /
    (1 - eccentricitySquared * sinPhi1 * sinPhi1) ** 1.5;
  const d = x / (n1 * k0);
  const latitude =
    phi1 -
    ((n1 * tanPhi1) / r1) *
      (d * d / 2 -
        ((5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * eccentricityPrimeSquared) * d ** 4) / 24 +
        ((61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * eccentricityPrimeSquared - 3 * c1 * c1) *
          d ** 6) /
          720);
  const longitude =
    ((d - ((1 + 2 * t1 + c1) * d ** 3) / 6 +
      ((5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * eccentricityPrimeSquared + 24 * t1 * t1) *
        d ** 5) /
        120) /
      cosPhi1) +
    degreesToRadians(-3);
  return { lat: (latitude * 180) / Math.PI, lng: (longitude * 180) / Math.PI };
}

function xmlValue(feature, tagName) {
  const match = new RegExp(`<${tagName}(?:\\s[^>]*)?>([\\s\\S]*?)</${tagName}>`).exec(feature);
  return match ? match[1].trim() : null;
}

function parseDgtSpeedLimitIndex(xml) {
  const signs = [];
  const features = xml.match(/<rst:GenericSafetyFeature\b[\s\S]*?<\/rst:GenericSafetyFeature>/g) || [];
  for (const feature of features) {
    if (!/<rst:type>\s*SpeedLimit\s*<\/rst:type>/.test(feature)) continue;
    const posList = xmlValue(feature, "gml:posList");
    const limitMatch = /<gml:measure[^>]*>([0-9.]+)<\/gml:measure>/.exec(feature);
    if (!posList || !limitMatch) continue;
    const coordinates = posList.match(/[+-]?\d+(?:\.\d+)?/g)?.map(Number) || [];
    const limit = Number(limitMatch[1]);
    if (coordinates.length < 2 || !Number.isFinite(limit) || limit < 5 || limit > 200) continue;
    const point = dgtUtm30ToWgs84(coordinates[0], coordinates[1]);
    if (!Number.isFinite(point.lat) || !Number.isFinite(point.lng)) continue;
    signs.push({
      ...point,
      limit,
      road: xmlValue(feature, "net:road"),
      direction: xmlValue(feature, "net:applicableDirection"),
    });
  }
  return signs;
}

async function fetchDgtSpeedLimitIndex() {
  const cache = globalThis.caches?.default;
  const cached = cache ? await cache.match(DGT_INDEX_CACHE_KEY) : null;
  if (cached) return cached.json();
  const response = await fetch(DGT_SPEED_LIMIT_URL, {
    headers: { "User-Agent": "CruizX/1.2 speed-limit service (https://cruizx.com)" },
  });
  if (!response.ok) throw new Error(`DGT ${response.status}`);
  const signs = parseDgtSpeedLimitIndex(await response.text());
  if (cache) {
    await cache.put(
      DGT_INDEX_CACHE_KEY,
      new Response(JSON.stringify(signs), {
        headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=604800" },
      })
    );
  }
  return signs;
}

async function fetchSpanishDgtSpeedLimit(query) {
  const signs = await fetchDgtSpeedLimitIndex();
  const nearby = signs
    .map((sign) => ({ ...sign, distance: roadDistanceMeters(query.position, sign, sign) }))
    .filter((sign) => sign.distance <= 28)
    .sort((a, b) => a.distance - b.distance);
  if (!nearby.length) {
    return speedLimitResponse({ country: "ES", source: "dgt_tnits", status: "unknown" });
  }
  const best = nearby[0];
  const conflictingSign = nearby.find((sign) => sign.limit !== best.limit && sign.distance - best.distance < 8);
  if (conflictingSign) {
    return speedLimitResponse({ country: "ES", source: "dgt_tnits", status: "ambiguous" });
  }
  return speedLimitResponse({
    country: "ES",
    limitKmh: best.limit,
    source: "dgt_tnits",
    status: "verified",
    confidence: "high",
  });
}

async function fetchFinnishSpeedLimit(query) {
  // The collection is WGS84 GeoJSON. This small geographic window is about
  // 100 x 100 m in Finland and is deliberately tighter than the matcher.
  const latitudeDelta = 0.00045;
  const longitudeDelta = 0.0009;
  const bbox = [
    query.position.lng - longitudeDelta,
    query.position.lat - latitudeDelta,
    query.position.lng + longitudeDelta,
    query.position.lat + latitudeDelta,
  ].join(",");
  const response = await fetch(
    `${FINTRAFFIC_SPEED_LIMIT_URL}?${new URLSearchParams({ bbox, limit: "200" })}`,
    { headers: { Accept: "application/geo+json", "User-Agent": "CruizX/1.2 speed-limit service" } }
  );
  if (!response.ok) {
    return speedLimitResponse({ country: "FI", source: "fintraffic_digiroad", status: "unavailable" });
  }
  const body = await response.json();
  const segments = [];
  for (const feature of body.features || []) {
    const limit = Number(feature.properties?.arvo);
    const coordinates = feature.geometry?.type === "LineString" ? feature.geometry.coordinates : [];
    for (let index = 0; index < coordinates.length - 1; index += 1) {
      const startRaw = coordinates[index];
      const endRaw = coordinates[index + 1];
      if (!Array.isArray(startRaw) || !Array.isArray(endRaw)) continue;
      segments.push({
        limit,
        start: { lng: Number(startRaw[0]), lat: Number(startRaw[1]) },
        end: { lng: Number(endRaw[0]), lat: Number(endRaw[1]) },
      });
    }
  }
  return matchOfficialSpeedSegments(query, segments, {
    country: "FI",
    source: "fintraffic_digiroad",
  });
}

async function fetchNorwegianSpeedLimit(query) {
  const projected = wgs84ToUtm33(query.position.lat, query.position.lng);
  // A 70 m square comfortably includes road geometry around a GPS fix, while
  // the common matcher below still requires a much tighter road match.
  const windowMeters = 70;
  const kartutsnitt = [
    projected.easting - windowMeters,
    projected.northing - windowMeters,
    projected.easting + windowMeters,
    projected.northing + windowMeters,
  ].join(",");
  const response = await fetch(
    `${NORWAY_NVDB_SPEED_LIMIT_URL}?${new URLSearchParams({
      antall: "200",
      kartutsnitt,
      inkluder: "geometri,egenskaper",
    })}`,
    { headers: { "X-Client": "CruizX speed-limit service (https://cruizx.com)" } }
  );
  if (!response.ok) {
    return speedLimitResponse({ country: "NO", source: "norway_nvdb", status: "unavailable" });
  }
  const body = await response.json();
  const segments = [];
  for (const object of body.objekter || []) {
    const speed = object.egenskaper?.find((property) => property?.navn === "Fartsgrense");
    const limit = Number(speed?.verdi);
    const points = parseNvdbWktLineString(object.geometri?.wkt);
    for (let index = 0; index < points.length - 1; index += 1) {
      segments.push({ limit, start: points[index], end: points[index + 1] });
    }
  }
  return matchOfficialSpeedSegments(query, segments, { country: "NO", source: "norway_nvdb" });
}

async function fetchSwedishSpeedLimit(query) {
  const response = await fetch(
    `${TRAFIKVERKET_SPEED_LIMIT_URL}?${new URLSearchParams({
      f: "json",
      geometry: JSON.stringify({ x: query.position.lng, y: query.position.lat }),
      geometryType: "esriGeometryPoint",
      inSR: "4326",
      spatialRel: "esriSpatialRelIntersects",
      distance: "30",
      units: "esriSRUnit_Meter",
      outFields: "Hastighet",
      returnGeometry: "true",
      outSR: "4326",
    })}`
  );
  if (!response.ok) {
    return speedLimitResponse({ country: "SE", source: "trafikverket_nvdb", status: "unavailable" });
  }

  const body = await response.json();
  const segments = [];
  for (const feature of body.features || []) {
    const limit = Number(feature.attributes?.Hastighet);
    if (!Number.isFinite(limit) || limit < 5 || limit > 200) continue;
    for (const rawPath of feature.geometry?.paths || []) {
      for (let index = 0; index < rawPath.length - 1; index += 1) {
        const startRaw = rawPath[index];
        const endRaw = rawPath[index + 1];
        if (!Array.isArray(startRaw) || !Array.isArray(endRaw)) continue;
        const start = { lng: Number(startRaw[0]), lat: Number(startRaw[1]) };
        const end = { lng: Number(endRaw[0]), lat: Number(endRaw[1]) };
        if (![start.lng, start.lat, end.lng, end.lat].every(Number.isFinite)) continue;
        segments.push({ limit, start, end });
      }
    }
  }
  return matchOfficialSpeedSegments(query, segments, {
    country: "SE",
    source: "trafikverket_nvdb",
  });
}

async function handleSpeedLimit(request, origin) {
  const query = parseSpeedLimitQuery(request);
  if (!query) {
    return json(
      { error: "invalid_request", message: "lat, lng, heading och country måste vara giltiga." },
      { status: 400 },
      origin
    );
  }

  const cache = globalThis.caches?.default;
  const cacheKey = speedLimitCacheRequest(query);
  const cached = cache ? await cache.match(cacheKey) : null;
  if (cached) {
    return json(await cached.json(), { headers: { "Cache-Control": "public, max-age=15", "X-CruizX-Cache": "HIT" } }, origin);
  }

  let result;
  try {
    result =
      query.country === "SE"
        ? await fetchSwedishSpeedLimit(query)
        : query.country === "ES"
          ? await fetchSpanishDgtSpeedLimit(query)
          : query.country === "FI"
            ? await fetchFinnishSpeedLimit(query)
            : query.country === "NO"
              ? await fetchNorwegianSpeedLimit(query)
              : speedLimitResponse({
                  country: query.country,
                  source: "pending_official_adapter",
                  status: "unknown",
                });
  } catch {
    result = speedLimitResponse({
      country: query.country,
      source:
        query.country === "SE"
          ? "trafikverket_nvdb"
          : query.country === "ES"
            ? "dgt_tnits"
            : query.country === "FI"
              ? "fintraffic_digiroad"
              : query.country === "NO"
                ? "norway_nvdb"
              : "pending_official_adapter",
      status: "unavailable",
    });
  }

  if (cache) {
    await cache.put(
      cacheKey,
      new Response(JSON.stringify(result), {
        headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=30" },
      })
    );
  }
  return json(result, { headers: { "Cache-Control": "public, max-age=15", "X-CruizX-Cache": "MISS" } }, origin);
}

// --- Trafikverket live traffic -------------------------------------

const TRAFIKVERKET_URL = "https://api.trafikinfo.trafikverket.se/v2/data.json";

function trafikverketPoint(wgs84) {
  const match = /POINT\s*\(([+-]?\d+(?:\.\d+)?)\s+([+-]?\d+(?:\.\d+)?)\)/i.exec(
    String(wgs84 || "")
  );
  if (!match) return null;
  const lng = Number(match[1]);
  const lat = Number(match[2]);
  return Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : null;
}

function parseTrafficCoordinates(request) {
  const url = new URL(request.url);
  const lat = finiteNumber(url.searchParams.get("lat"), -90, 90);
  const lng = finiteNumber(url.searchParams.get("lng"), -180, 180);
  const requestedRadius = finiteNumber(url.searchParams.get("radius_km") || "50", 5, 75);
  if (lat === null || lng === null || requestedRadius === null) return null;
  return { lat, lng, requestedRadius };
}

function trafficCacheContext(lat, lng, requestedRadius) {
  const cellSize = 0.05;
  const queryLat = Math.round(lat / cellSize) * cellSize;
  const queryLng = Math.round(lng / cellSize) * cellSize;
  const radiusKm = Math.ceil(requestedRadius / 10) * 10 + 5;
  const cacheKey = new Request(
    `https://cruizx-traffic-cache.invalid/incidents?lat=${queryLat.toFixed(2)}` +
      `&lng=${queryLng.toFixed(2)}&radius_km=${radiusKm}`
  );
  return { queryLat, queryLng, radiusKm, cacheKey };
}

function trafikverketBoundingBox(queryLat, queryLng, radiusKm) {
  const latDelta = radiusKm / 111.0;
  const cosLat = Math.max(0.2, Math.cos((queryLat * Math.PI) / 180));
  const lngDelta = radiusKm / (111.0 * cosLat);
  return {
    minLat: queryLat - latDelta,
    maxLat: queryLat + latDelta,
    minLng: queryLng - lngDelta,
    maxLng: queryLng + lngDelta,
  };
}

function trafikverketQueryXml(apiKey, bounds) {
  return `<REQUEST>
  <LOGIN authenticationkey="${apiKey}" />
  <QUERY objecttype="Situation" namespace="Road.TrafficInfo" schemaversion="1.6" limit="150">
    <FILTER>
      <WITHIN name="Deviation.Geometry.WGS84" shape="box" value="${bounds.minLng} ${bounds.minLat}, ${bounds.maxLng} ${bounds.maxLat}" />
    </FILTER>
  </QUERY>
</REQUEST>`;
}

function boolString(value) {
  return String(value).toLowerCase() === "true";
}

function asArray(value) {
  if (Array.isArray(value)) return value;
  return value ? [value] : [];
}

function parseDeviationTimeRange(deviation) {
  const startTime = deviation?.StartTime ? String(deviation.StartTime) : null;
  const endTime = deviation?.EndTime ? String(deviation.EndTime) : null;
  return { startTime, endTime };
}

function isDeviationActive(startTime, endTime, nowMs) {
  if (startTime && Date.parse(startTime) > nowMs) return false;
  if (endTime && Date.parse(endTime) < nowMs) return false;
  return true;
}

function buildIncident(id, point, deviation, startTime, endTime) {
  return {
    id,
    ...point,
    header: String(deviation?.Header || ""),
    road_number: String(deviation?.RoadNumber || ""),
    icon_id: String(deviation?.IconId || ""),
    message_code: String(deviation?.MessageCode || ""),
    severity: String(deviation?.SeverityCode || ""),
    start_time: startTime,
    end_time: endTime,
  };
}

function collectDeviationIncident(deviation, seen, nowMs) {
  if (boolString(deviation?.Suspended)) return null;

  const point = trafikverketPoint(deviation?.Geometry?.WGS84);
  if (!point) return null;

  const id = String(deviation?.Id || "");
  if (!id || seen.has(id)) return null;

  const { startTime, endTime } = parseDeviationTimeRange(deviation);
  if (!isDeviationActive(startTime, endTime, nowMs)) return null;

  seen.add(id);
  return buildIncident(id, point, deviation, startTime, endTime);
}

function collectTrafficIncidents(result) {
  const incidents = [];
  const seen = new Set();
  const nowMs = Date.now();

  for (const situation of result.Situation || []) {
    if (boolString(situation?.Deleted)) continue;

    for (const deviation of asArray(situation.Deviation)) {
      const incident = collectDeviationIncident(deviation, seen, nowMs);
      if (incident) incidents.push(incident);
    }
  }

  return incidents;
}

async function fetchTrafficPayload(xmlBody) {
  let response;
  try {
    response = await fetch(TRAFIKVERKET_URL, {
      method: "POST",
      headers: { "Content-Type": "text/xml", Accept: "application/json" },
      body: xmlBody,
    });
  } catch (error) {
    return { error: { error: "traffic_service_unavailable", detail: String(error) }, status: 502 };
  }

  if (!response.ok) {
    return {
      error: { error: "traffic_service_unavailable", status: response.status },
      status: 502,
    };
  }

  try {
    const payload = await response.json();
    return { payload };
  } catch (_) {
    return { error: { error: "traffic_service_invalid_response" }, status: 502 };
  }
}

async function handleTrafficIncidents(request, env, origin) {
  if (!env.TRAFIKVERKET_KEY) {
    return json({ error: "traffic_service_not_configured" }, { status: 503 }, origin);
  }

  const coordinates = parseTrafficCoordinates(request);
  if (!coordinates) {
    return json(
      { error: "invalid_coordinates", message: "lat, lng och radius_km måste vara giltiga tal." },
      { status: 400 },
      origin
    );
  }
  const { lat, lng, requestedRadius } = coordinates;

  // Nearby clients share one cache entry. The query radius is expanded to
  // cover users close to a grid-cell edge.
  const { queryLat, queryLng, radiusKm, cacheKey } = trafficCacheContext(lat, lng, requestedRadius);
  const cache = caches.default;
  const cached = await cache.match(cacheKey);
  if (cached) {
    const data = await cached.json();
    return json(
      data,
      { headers: { "Cache-Control": "public, max-age=30", "X-CruizX-Cache": "HIT" } },
      origin
    );
  }

  const bounds = trafikverketBoundingBox(queryLat, queryLng, radiusKm);
  const query = trafikverketQueryXml(env.TRAFIKVERKET_KEY, bounds);
  const fetched = await fetchTrafficPayload(query);
  if (fetched.error) {
    return json(fetched.error, { status: fetched.status }, origin);
  }
  const payload = fetched.payload;

  const result = payload?.RESPONSE?.RESULT?.[0] || {};
  const incidents = collectTrafficIncidents(result);

  const data = {
    source: "trafikverket",
    center: { lat: queryLat, lng: queryLng },
    radius_km: radiusKm,
    fetched_at: new Date().toISOString(),
    count: incidents.length,
    incidents,
  };
  await cache.put(
    cacheKey,
    new Response(JSON.stringify(data), {
      headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=60" },
    })
  );
  return json(
    data,
    { headers: { "Cache-Control": "public, max-age=30", "X-CruizX-Cache": "MISS" } },
    origin
  );
}

// --- Entry ----------------------------------------------------------

const APK_REDIRECT_PATHS = new Set([
  "/api/download/apk",
  "/api/download/apk/1.1.4-127",
  "/api/download/apk/1.2.0-136",
  "/api/download/apk/1.2.0-167",
]);
const APK_REDIRECT_URL =
  "https://github.com/Kimsjogren/SlowRide/releases/download/v1.2.0-167/CruizX-1.2.0-167-free.apk";

function handleApkDownload(request, env) {
  // Log download event (fire-and-forget)
  const ip = request.headers.get("CF-Connecting-IP") || "";
  const ua = request.headers.get("User-Agent") || "";
  logEvent(env, "apk_download", "website", "", ip, { ua }).catch(() => {});
  return new Response(null, {
    status: 302,
    headers: {
      Location: APK_REDIRECT_URL,
      "Cache-Control": "no-store",
    },
  });
}

function routeRequest(request, env, origin, pathname) {
  const routeKey = `${request.method} ${pathname}`;
  const routes = {
    "POST /api/claim": () => handleClaim(request, env, origin),
    "POST /api/scan": () => handleScan(request, env, origin),
    "GET /api/stats": () => handleStats(request, env, origin),
    "GET /api/map/speed-bumps": () => handleSpeedBumps(request, origin),
    "GET /api/map/speed-limit": () => handleSpeedLimit(request, origin),
    "GET /api/traffic/incidents": () => handleTrafficIncidents(request, env, origin),
    "POST /api/ai/route-analysis": () => handleAiRouteAnalysis(request, env, origin),
    "POST /api/ai/report": () => handleAiReport(request, env, origin),
    "POST /api/support/notify": () => handleSupportNotify(request, env),
    "GET /api/support/guest": () => handleGuestSupport(request, env, origin),
    "POST /api/support/guest": () => handleGuestSupport(request, env, origin),
    "GET /api/support/conversation": () => handleSupportConversation(request, env, origin),
    "POST /api/support/reply": () => handleSupportReply(request, env, origin),
    "GET /api/support/faq": () => handleSupportFaq(request, origin),
    "POST /api/support/faq": () => handleSupportFaq(request, origin),
    "GET /api/web/pricing": () => handleWebPricing(env, origin),
    "POST /api/web/checkout-session": () => handleWebCheckoutSession(request, env, origin),
    "POST /api/web/stripe-webhook": () => handleStripeWebhook(request, env),
  };

  return routes[routeKey] || null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin") || "";
    const { pathname } = url;

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders(origin) });
    }

    if (request.method === "GET" && APK_REDIRECT_PATHS.has(pathname)) {
      return handleApkDownload(request, env);
    }

    const handler = routeRequest(request, env, origin, pathname);
    if (handler) {
      return handler();
    }

    return json({ error: "not_found" }, { status: 404 }, origin);
  },
};
