import assert from "node:assert/strict";
import test from "node:test";

import worker from "./worker.js";

const userId = "4de0a0c1-c42e-4dc2-9e8c-7acd9693b3da";
const baseEnv = {
  SUPABASE_URL: "https://example.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "service-role",
  SUPPORT_WEBHOOK_SECRET: "webhook-secret",
  SUPPORT_REPLY_SECRET: "reply-secret",
  NTFY_SERVER_URL: "https://ntfy.example",
  NTFY_TOPIC: "private-topic",
  NTFY_ACCESS_TOKEN: "ntfy-token",
};

async function signature(user, expires) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(baseEnv.SUPPORT_REPLY_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const bytes = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${user}.${expires}`)
  );
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

test("support webhook requires its shared secret", { concurrency: false }, async () => {
  const response = await worker.fetch(
    new Request("https://cruizx.com/api/support/notify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    }),
    baseEnv
  );
  assert.equal(response.status, 401);
});

test("speed-limit endpoint verifies a matching Swedish NVDB segment", { concurrency: false }, async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = input instanceof Request ? input.url : String(input);
    assert.match(url, /vektor\.trafikverket\.se/);
    return Response.json({
      features: [
        {
          attributes: { Hastighet: 50 },
          geometry: {
            paths: [[[18.0, 58.9997], [18.0, 59.0003]]],
          },
        },
      ],
    });
  };

  try {
    const response = await worker.fetch(
      new Request(
        "https://cruizx.com/api/map/speed-limit?lat=59&lng=18&heading=0&country=SE"
      ),
      baseEnv
    );
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.country, "SE");
    assert.equal(body.limit_kmh, 50);
    assert.equal(body.source, "trafikverket_nvdb");
    assert.equal(body.status, "verified");
    assert.equal(body.confidence, "high");
    assert.match(body.checked_at, /^\d{4}-\d{2}-\d{2}T/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("speed-limit endpoint returns unknown instead of guessing when a DGT sign is not nearby", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(
      '<?xml version="1.0"?><rst:ROSATTESafetyFeatureDataset><rst:GenericSafetyFeature><rst:type>SpeedLimit</rst:type><rst:encodedGeometry><gml:LineString><gml:posList>4573173.06589931 ,586682.47564207</gml:posList></gml:LineString></rst:encodedGeometry><rst:properties><gml:measure uom="kmph">40</gml:measure></rst:properties></rst:GenericSafetyFeature></rst:ROSATTESafetyFeatureDataset>'
    );
  try {
    const response = await worker.fetch(
      new Request(
        "https://cruizx.com/api/map/speed-limit?lat=40.4168&lng=-3.7038&heading=90&country=ES"
      ),
      baseEnv
    );
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.country, "ES");
    assert.equal(body.limit_kmh, null);
    assert.equal(body.source, "dgt_tnits");
    assert.equal(body.status, "unknown");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("speed-limit endpoint verifies a matching Finnish DigiRoad segment", { concurrency: false }, async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = input instanceof Request ? input.url : String(input);
    assert.match(url, /vaylapilvi\.fi\/vaylatiedot\/digiroad/);
    assert.match(url, /bbox=/);
    return Response.json({
      features: [
        {
          properties: { arvo: 80 },
          geometry: {
            type: "LineString",
            coordinates: [[22.82575, 61.1175], [22.82575, 61.1182]],
          },
        },
      ],
    });
  };
  try {
    const response = await worker.fetch(
      new Request(
        "https://cruizx.com/api/map/speed-limit?lat=61.1178&lng=22.82575&heading=0&country=FI"
      ),
      baseEnv
    );
    const body = await response.json();
    assert.equal(body.limit_kmh, 80);
    assert.equal(body.source, "fintraffic_digiroad");
    assert.equal(body.status, "verified");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("speed-limit endpoint verifies a matching Norwegian NVDB segment", { concurrency: false }, async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = input instanceof Request ? input.url : String(input);
    assert.match(url, /nvdbapiles\.atlas\.vegvesen\.no/);
    assert.match(url, /kartutsnitt=/);
    return Response.json({
      objekter: [
        {
          egenskaper: [{ navn: "Fartsgrense", verdi: 50 }],
          geometri: {
            wkt: "LINESTRING Z (25397.223 6855337.889 230.33,25407.855 6855341.153 230.59)",
          },
        },
      ],
    });
  };
  try {
    const response = await worker.fetch(
      new Request(
        "https://cruizx.com/api/map/speed-limit?lat=61.53758&lng=6.0539&heading=90&country=NO"
      ),
      baseEnv
    );
    const body = await response.json();
    assert.equal(body.limit_kmh, 50);
    assert.equal(body.source, "norway_nvdb");
    assert.equal(body.status, "verified");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("AI route analysis accepts Car and guards an unverified RoadScore", { concurrency: false }, async () => {
  const originalFetch = globalThis.fetch;
  let aiInput;
  globalThis.fetch = async (input, init = {}) => {
    const url = input instanceof Request ? input.url : String(input);
    if (url.endsWith("/auth/v1/user")) {
      return Response.json({ id: userId });
    }
    if (url.includes("/rest/v1/flyer_events?") && (!init.method || init.method === "GET")) {
      return Response.json([]);
    }
    if (url.endsWith("/rest/v1/flyer_events") && init.method === "POST") {
      return new Response(null, { status: 201 });
    }
    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const response = await worker.fetch(
      new Request("https://cruizx.com/api/ai/route-analysis", {
        method: "POST",
        headers: {
          "Authorization": "Bearer test-token",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          language: "sv",
          vehicle_type: "Car",
          country_code: "SE",
          max_speed_kmh: 90,
          route: {
            distance_km: 3.2,
            duration_minutes: 8,
            street_names: ["Tyresövägen"],
          },
          alert_counts: {},
          road_score: {
            score: 45,
            grade: "unverified",
            legally_verified: false,
            route_alert_count: 0,
            complex_turn_count: 2,
            distance_detour_percent: 4,
            duration_detour_percent: 3,
            factors: {},
          },
        }),
      }),
      {
        ...baseEnv,
        DEVICE_SALT: "device-salt",
        AI: {
          run: async (model, input) => {
            aiInput = input;
            assert.equal(model, "@cf/meta/llama-3.1-8b-instruct-fast");
            return {
              response: JSON.stringify({
                headline: "Rutten ser bra ut",
                summary: "En kort rutt för bil.",
                suitability: "good",
                highlights: ["Kort restid"],
                cautions: [],
                recommendation: "Följ skyltningen längs vägen.",
              }),
            };
          },
        },
      }
    );

    assert.equal(response.status, 200);
    const responseBody = await response.json();
    assert.equal(responseBody.suitability, "caution");
    const facts = JSON.parse(aiInput.messages[1].content);
    assert.equal(facts.vehicle_type, "Car");
    assert.match(facts.vehicle_context, /standard passenger car/i);
    assert.equal(facts.road_score.score, 45);
    assert.equal(facts.road_score.legally_verified, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("support FAQ serves its offline catalog and matches prepared answers", { concurrency: false }, async () => {
  const catalogResponse = await worker.fetch(
    new Request("https://cruizx.com/api/support/faq"),
    baseEnv
  );
  assert.equal(catalogResponse.status, 200);
  const catalog = await catalogResponse.json();
  assert.equal(catalog.version, 1);
  assert.equal(catalog.entries.length, 7);

  const matchResponse = await worker.fetch(
    new Request("https://cruizx.com/api/support/faq", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        question: "AI kolla rutten fungerar inte",
        language_code: "sv",
      }),
    }),
    baseEnv
  );
  assert.equal(matchResponse.status, 200);
  const match = await matchResponse.json();
  assert.equal(match.matched, true);
  assert.equal(match.entry.id, "ai_route");
  assert.match(match.entry.answer, /4 analyser per dag/);
});

test("new user support messages are mirrored to ntfy with a reply action", { concurrency: false }, async () => {
  const originalFetch = globalThis.fetch;
  let ntfyRequest;
  globalThis.fetch = async (input, init = {}) => {
    const url = input instanceof Request ? input.url : String(input);
    if (url.includes("/auth/v1/admin/users/")) {
      return Response.json({ id: userId, email: "driver@example.com" });
    }
    if (url === baseEnv.NTFY_SERVER_URL) {
      ntfyRequest = { init, payload: JSON.parse(init.body) };
      return Response.json({ id: "notification-id" });
    }
    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const response = await worker.fetch(
      new Request("https://cruizx.com/api/support/notify", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CruizX-Webhook-Secret": baseEnv.SUPPORT_WEBHOOK_SECRET,
        },
        body: JSON.stringify({
          record: { user_id: userId, sender: "user", body: "Jag behöver hjälp" },
        }),
      }),
      baseEnv
    );
    assert.equal(response.status, 200);
    assert.equal(ntfyRequest.init.headers.Authorization, "Bearer ntfy-token");
    assert.equal(ntfyRequest.payload.topic, "private-topic");
    assert.match(ntfyRequest.payload.message, /Jag behöver hjälp/);
    assert.equal(ntfyRequest.payload.actions[0].label, "Svara");
    assert.match(ntfyRequest.payload.actions[0].url, /support-reply\.html/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("signed support link can load a conversation and post a reply", { concurrency: false }, async () => {
  const expires = Math.floor(Date.now() / 1000) + 3600;
  const signed = await signature(userId, expires);
  const query = new URLSearchParams({ user: userId, expires: String(expires), signature: signed });
  const originalFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (input, init = {}) => {
    const url = input instanceof Request ? input.url : String(input);
    calls.push({ url, init });
    if (url.includes("/auth/v1/admin/users/")) {
      return Response.json({ id: userId, email: "driver@example.com" });
    }
    if (url.includes("/rest/v1/support_messages") && (!init.method || init.method === "GET")) {
      return Response.json([
        {
          id: "message-1",
          sender: "user",
          body: "Hej",
          language_code: "sv",
          created_at: "2026-08-01T12:00:00Z",
          read_at: null,
        },
      ]);
    }
    if (url.includes("/rest/v1/support_messages") && init.method === "PATCH") {
      return new Response(null, { status: 204 });
    }
    if (url.endsWith("/rest/v1/support_messages") && init.method === "POST") {
      return Response.json([{ id: "reply-1", ...JSON.parse(init.body) }], { status: 201 });
    }
    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const conversation = await worker.fetch(
      new Request(`https://cruizx.com/api/support/conversation?${query}`),
      baseEnv
    );
    assert.equal(conversation.status, 200);
    const conversationBody = await conversation.json();
    assert.equal(conversationBody.user.email, "driver@example.com");
    assert.equal(conversationBody.messages[0].body, "Hej");

    const reply = await worker.fetch(
      new Request(`https://cruizx.com/api/support/reply?${query}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "Hej! Hur kan vi hjälpa?" }),
      }),
      baseEnv
    );
    assert.equal(reply.status, 201);
    const insert = calls.find(
      (call) => call.url.endsWith("/rest/v1/support_messages") && call.init.method === "POST"
    );
    assert.deepEqual(JSON.parse(insert.init.body), {
      user_id: userId,
      sender: "support",
      body: "Hej! Hur kan vi hjälpa?",
      language_code: "sv",
    });
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("guest support uses a hashed device token for private messages", { concurrency: false }, async () => {
  const originalFetch = globalThis.fetch;
  const guestToken = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ";
  let insertedPayload;
  globalThis.fetch = async (input, init = {}) => {
    const url = input instanceof Request ? input.url : String(input);
    if (url.includes("/rest/v1/support_messages?select=") && url.includes("guest_token_hash=eq.")) {
      return Response.json([
        {
          id: "1",
          user_id: null,
          sender: "support",
          body: "Hej gäst!",
          language_code: "sv",
          created_at: "2026-08-02T05:00:00Z",
          read_at: null,
        },
      ]);
    }
    if (url.includes("/rest/v1/support_messages?guest_token_hash=eq.")) {
      return new Response(null, { status: 204 });
    }
    if (url.endsWith("/rest/v1/rpc/insert_guest_support_message")) {
      insertedPayload = JSON.parse(init.body);
      return Response.json({ id: "2", sender: "user", body: insertedPayload.p_body });
    }
    throw new Error(`Unexpected URL: ${url}`);
  };

  try {
    const headers = { "X-CruizX-Guest-Token": guestToken };
    const getResponse = await worker.fetch(
      new Request("https://cruizx.com/api/support/guest", { headers }),
      baseEnv
    );
    assert.equal(getResponse.status, 200);
    const conversation = await getResponse.json();
    assert.equal(conversation.messages[0].body, "Hej gäst!");

    const postResponse = await worker.fetch(
      new Request("https://cruizx.com/api/support/guest", {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify({ body: "Jag behöver hjälp", language_code: "sv" }),
      }),
      baseEnv
    );
    assert.equal(postResponse.status, 201);
    assert.equal(insertedPayload.p_body, "Jag behöver hjälp");
    assert.match(insertedPayload.p_guest_token_hash, /^[a-f0-9]{64}$/);
    assert.notEqual(insertedPayload.p_guest_token_hash, guestToken);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
