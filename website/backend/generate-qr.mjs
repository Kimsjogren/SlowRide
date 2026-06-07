#!/usr/bin/env node
/*
 * Genererar QR-kod med CruizX-loggan i mitten.
 *   node generate-qr.mjs <url> <output.png> [--logo path] [--size 1200]
 *
 * Använder error correction level H (30 %) så att det är OK att täcka
 * mitten med en logo.
 */
import QRCode from "qrcode";
import sharp from "sharp";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error("Användning: node generate-qr.mjs <url> <output.png> [--logo path] [--size 1200]");
  process.exit(1);
}

const url = args[0];
const out = path.resolve(args[1]);
let logoPath = path.resolve(here, "../assets/logga_nobg.png");
let size = 1200;
for (let i = 2; i < args.length; i++) {
  if (args[i] === "--logo") logoPath = path.resolve(args[++i]);
  else if (args[i] === "--size") size = parseInt(args[++i], 10);
}

const qrBuf = await QRCode.toBuffer(url, {
  errorCorrectionLevel: "H",
  margin: 2,
  width: size,
  color: { dark: "#06111f", light: "#ffffff" },
});

// Loggan placeras direkt på QR-koden utan vit ram. Hålls liten (~18 %)
// eftersom error correction H tål upp till ~30 % skadad yta.
const logoSize = Math.round(size * 0.18);

const logoResized = await sharp(logoPath)
  .resize(logoSize, logoSize, { fit: "contain", background: { r: 0, g: 0, b: 0, alpha: 0 } })
  .png()
  .toBuffer();

await sharp(qrBuf)
  .composite([{ input: logoResized, gravity: "center" }])
  .png()
  .toFile(out);

console.log(`✓ QR sparad: ${out}`);
console.log(`  URL:   ${url}`);
console.log(`  Logo:  ${logoPath}`);
console.log(`  Storlek: ${size}×${size}px`);
