# CruizX claim backend

Två komponenter:

- **Supabase** lagrar koder + events ([schema.sql](schema.sql)).
- **Cloudflare Worker** på `cruizx.com/api/*` är publik endpoint som tilldelar nästa kod atomärt ([worker.js](worker.js)).

## Engångsuppsättning

### 1. Supabase

1. Skapa projekt på supabase.com (eller använd ditt befintliga).
2. Kör innehållet i [schema.sql](schema.sql) i SQL editor.
3. Hämta `Project URL` och `service_role` key från Project Settings → API.

### 2. Importera koderna

```bash
cd backend
export SUPABASE_URL="https://<projekt>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."   # service_role, inte anon
node import-codes.mjs ~/Downloads/OfferCodeOneTimeUseCodes_515517.csv Flyer2026
```

Kör samma kommando varje gång du genererar nya batch-koder i App Store Connect — dubbletter ignoreras.

### 3. Cloudflare Worker

```bash
npm install -g wrangler
cd backend
wrangler login
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SERVICE_ROLE_KEY
wrangler secret put DEVICE_SALT          # kör: openssl rand -hex 32
wrangler secret put STATS_TOKEN          # valfri sträng, för /api/stats
wrangler secret put STRIPE_SECRET_KEY
wrangler secret put STRIPE_WEBHOOK_SECRET
wrangler secret put STRIPE_PRICE_ID
wrangler secret put WEB_CHECKOUT_SUCCESS_URL
wrangler secret put WEB_CHECKOUT_CANCEL_URL
wrangler secret put TRAFIKVERKET_KEY
wrangler secret put SUPPORT_WEBHOOK_SECRET
wrangler secret put SUPPORT_REPLY_SECRET
wrangler secret put NTFY_SERVER_URL
wrangler secret put NTFY_TOPIC
wrangler secret put NTFY_ACCESS_TOKEN       # om ntfy-topic är skyddad
wrangler deploy
```

Verifiera att routen `cruizx.com/api/*` är aktiv i Cloudflare dashboard → Workers Routes.

## Endpoints

- `POST /api/claim`: Tilldelar nästa lediga kod till enheten.
- `POST /api/scan`: Loggar QR-scan (frivilligt, ingen body).
- `GET /api/stats`: Returnerar `flyer_stats`-vyn. Header: `X-Stats-Token: <STATS_TOKEN>`.
- `GET /api/web/pricing`: Returnerar aktivt Stripe-pris för webb/APK, lokaliserat per språk.
- `GET /api/traffic/incidents`: Returnerar cachelagrade, normaliserade livehändelser från Trafikverket utan att exponera API-nyckeln i appen.
- `GET /api/map/speed-limit`: Returnerar endast en verifierad skyltad hastighetsgräns för aktuellt vägsegment. Parametrar: `lat`, `lng`, `heading`, `country` och valfritt `route_lat`, `route_lng`. Osäkert eller saknat svar returneras som `limit_kmh: null` — aldrig som en gissning. Officiella adaptrar: Trafikverkets NVDB (Sverige), NVDB (Norge), Fintraffic DigiRoad (Finland) och DGT TN-ITS/ROSATTE R-301 (Spaniens statliga vägnät). Danmark och Frankrike returnerar säkert `unknown` tills respektive nationella adapter är aktiverad.
- `POST /api/ai/route-analysis`: Analyserar begränsade ruttfakta och det deterministiska CruizX RoadScore-betyget med Workers AI för en inloggad användare. AI:n får förklara men aldrig räkna om eller motsäga betyget. GPS-koordinater skickas inte. Appen tillåter 4 anrop per dag för Free och 15 för Pro; Worker-skyddet stoppar vid 15 anrop per användare och dag samt Cloudflares kostnadsfria dagstilldelning.
- `POST /api/ai/report`: Rapporterar ett AI-svar för uppföljning.
- `GET /api/support/faq`: Levererar den versionsstyrda FAQ-katalog som appen även har som offline-reserv.
- `POST /api/support/faq`: Matchar en fråga mot kvalitetssäkrade standardsvar utan en extern AI-leverantör.
- `POST /api/support/notify`: Tar emot signerade databasnotiser och skickar nya användarmeddelanden till ntfy.
- `GET /api/support/conversation`: Visar konversationen för en tidsbegränsad signerad svarslänk.
- `POST /api/support/reply`: Skickar ett supportsvar till användarens CruizX-chatt.
- `POST /api/web/checkout-session`: Skapar Stripe Checkout Session (`mode=subscription`).
- `POST /api/web/stripe-webhook`: Tar emot Stripe events och uppdaterar `web_subscriptions`.

### Statistik

```bash
curl -H "X-Stats-Token: $STATS_TOKEN" https://cruizx.com/api/stats
```

Du ser: `total_codes`, `claimed_codes`, `scans`, `new_claims`, `repeat_views`.

## Säkerhet

- Service-key finns ENDAST i Worker-secrets.
- RLS är på, ingen policy → anon/authenticated kan inget direkt mot Supabase.
- Enhets-ID hashas tillsammans med IP+UA+salt innan det sparas.
- En enhet (cookie) får en kod per kampanj — försök efteråt returnerar samma kod.
- För ännu hårdare skydd: aktivera Cloudflare Turnstile på `/download` och skicka token i `/api/claim`.

## Web subscription (auto-Pro i webbappen)

Kör även SQL-delen för `web_subscriptions` i [schema.sql](schema.sql).

Flöde:

1. Flutter/webb eller frontend kallar `POST /api/web/checkout-session` med `{ uid, email }`.
1. Worker skapar Stripe Checkout Session med metadata `uid` och returnerar `url`.
1. Frontend öppnar `url` och användaren genomför betalning.
1. Stripe skickar event till `POST /api/web/stripe-webhook`.
1. Workern upsertar en rad i `public.web_subscriptions` med `user_id`, `provider`, `external_customer`, `external_sub`, `status` och `current_period_end`.
1. Flutter-webbappen läser tabellen med RLS-policy `auth.uid() = user_id` och växlar Pro automatiskt.

Exempel: skapa checkout session

```bash
curl -X POST https://cruizx.com/api/web/checkout-session \
  -H "Content-Type: application/json" \
  -d '{"uid":"<supabase-user-uuid>","email":"name@example.com"}'
```

Notering:

- Klienten skriver inte till tabellen.
- Endast webhook/backend med service-role ska uppdatera subscription-status.

## Supportnotiser via ntfy

Migrationen `20260801123000_support_ntfy_notifications.sql` skickar nya rader
med `sender = 'user'` till Worker-endpointen. Lägg dessa två värden i
Supabase Vault innan flödet aktiveras:

- `support_webhook_url`: `https://cruizx.com/api/support/notify`
- `support_webhook_secret`: samma slumpmässiga värde som Worker-secret
  `SUPPORT_WEBHOOK_SECRET`

ntfy-notisen innehåller en svarsknapp med en signerad länk som gäller i sju
dagar. Service-role, ntfy-token och signeringshemligheter skickas aldrig till
appen eller webbläsaren.

## Ändra Pro-priset

För webb/APK är `Stripe Price ID` nu den gemensamma sanningskällan.

Flöde:

1. Skapa eller aktivera rätt pris i Stripe.
1. Uppdatera Worker-secret:

```bash
wrangler secret put STRIPE_PRICE_ID
```

1. Deploya workern:

```bash
wrangler deploy
```

Efter det hämtar:

- `Flutter` (webb/APK Stripe-spåret) priset från `GET /api/web/pricing`
- `hemsidan` priset från samma endpoint

För `iPhone / App Store` ändrar du fortfarande priset i `App Store Connect`, eftersom iOS läser priset direkt från Apple.
