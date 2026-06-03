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
wrangler deploy
```
Verifiera att routen `cruizx.com/api/*` är aktiv i Cloudflare dashboard → Workers Routes.

## Endpoints

| Metod | Path | Syfte |
|-------|------|-------|
| POST  | `/api/claim` | Tilldelar nästa lediga kod till enheten |
| POST  | `/api/scan`  | Loggar QR-scan (frivilligt, ingen body) |
| GET   | `/api/stats` | Returnerar `flyer_stats`-vyn. Header: `X-Stats-Token: <STATS_TOKEN>` |

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
