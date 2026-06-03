/*
 * CruizX claim API — Cloudflare Worker
 * ---------------------------------------------------------------
 * Routes:
 *   POST /api/claim   → returnerar { code, redeem_url, repeat }
 *   POST /api/scan    → logga en QR-scan (no-op om redan loggad)
 *   GET  /api/stats   → enkel översikt (skyddad med STATS_TOKEN)
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
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(origin),
      ...(init.headers || {}),
    },
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
  return crypto.randomUUID().replace(/-/g, "");
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
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/flyer_stats?select=*`, {
    headers: {
      "apikey": env.SUPABASE_SERVICE_ROLE_KEY,
      "Authorization": `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
    },
  });
  return json(await res.json(), { status: res.status }, origin);
}

// --- Entry ----------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin") || "";

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders(origin) });
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

    return json({ error: "not_found" }, { status: 404 }, origin);
  },
};
