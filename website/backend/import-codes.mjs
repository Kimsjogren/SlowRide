#!/usr/bin/env node
/*
 * import-codes.mjs — importera CSV från App Store Connect till Supabase.
 *
 * Användning:
 *   export SUPABASE_URL="https://<projekt>.supabase.co"
 *   export SUPABASE_SERVICE_ROLE_KEY="..."   # service-key, INTE anon!
 *   node import-codes.mjs ~/Downloads/OfferCodeOneTimeUseCodes_515517.csv Flyer2026
 *
 * CSV-format (utan header):
 *   <CODE>,<REDEEM_URL>
 */

import fs from "node:fs";
import readline from "node:readline";

const [, , csvPath, campaign = "Flyer2026"] = process.argv;

if (!csvPath) {
  console.error("Usage: node import-codes.mjs <csv-path> [campaign]");
  process.exit(1);
}

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars.");
  process.exit(1);
}

const rows = [];
const rl = readline.createInterface({ input: fs.createReadStream(csvPath) });
for await (const line of rl) {
  const trimmed = line.trim();
  if (!trimmed) continue;
  const [code, url] = trimmed.split(",");
  if (!code || !url) continue;
  rows.push({ code, campaign, redeem_url: url });
}

console.log(`Importing ${rows.length} codes into campaign "${campaign}"…`);

// Batcha 500 åt gången
const CHUNK = 500;
for (let i = 0; i < rows.length; i += CHUNK) {
  const batch = rows.slice(i, i + CHUNK);
  const res = await fetch(`${SUPABASE_URL}/rest/v1/offer_codes?on_conflict=code`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": SERVICE_KEY,
      "Authorization": `Bearer ${SERVICE_KEY}`,
      "Prefer": "resolution=ignore-duplicates,return=minimal",
    },
    body: JSON.stringify(batch),
  });
  if (!res.ok) {
    console.error(`Batch ${i} failed:`, res.status, await res.text());
    process.exit(1);
  }
  console.log(`  …${Math.min(i + CHUNK, rows.length)}/${rows.length}`);
}

console.log("Done.");
