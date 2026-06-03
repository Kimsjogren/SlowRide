/*
 * CruizX – Flyer2026 claim flow (browser-side).
 * Pratar med /api/claim (Cloudflare Worker → Supabase).
 */

// Samma origin när siten ligger på cruizx.com. Sätt t.ex.
// "https://cruizx.com" om du testar download.html lokalt.
const API_BASE = "";

const claimBtn    = document.querySelector("#claim-btn");
const resultBox   = document.querySelector("#code-result");
const resultLabel = document.querySelector("#code-result-label");
const codeText    = document.querySelector("#code-value-text");
const copyBtn     = document.querySelector("#copy-btn");
const redeemLink  = document.querySelector("#redeem-link");

const LOCAL_KEY = "cruizx.flyer2026.lastCode"; // cache så reload visar samma kod

// Turnstile-token, sätts av callbacks i HTML
let turnstileToken = null;
window.onTurnstileSuccess = (token) => {
  turnstileToken = token;
  claimBtn.disabled = false;
};
window.onTurnstileExpired = () => {
  turnstileToken = null;
  claimBtn.disabled = true;
};
window.onTurnstileError = () => {
  turnstileToken = null;
  claimBtn.disabled = true;
};

function showCode(code, redeemUrl, { repeat = false } = {}) {
  resultBox.classList.add("visible");
  resultBox.classList.remove("error");
  resultLabel.textContent = repeat
    ? "Du har redan hämtat denna kod"
    : "Din kod – lös in i App Store";
  codeText.textContent = code;
  redeemLink.style.display = "";
  redeemLink.href = redeemUrl
    || `https://apps.apple.com/redeem?ctx=offercodes&id=6760605501&code=${encodeURIComponent(code)}`;
  claimBtn.disabled = true;
  claimBtn.textContent = "Kod hämtad";
}

function showError(message) {
  resultBox.classList.add("visible", "error");
  resultLabel.textContent = "Något gick fel";
  codeText.textContent = message;
  redeemLink.style.display = "none";
  claimBtn.disabled = false;
  claimBtn.textContent = "Försök igen";
}

async function claimCode() {
  if (!turnstileToken) {
    showError("Vänligen klara säkerhetskontrollen först.");
    return;
  }
  let res;
  try {
    res = await fetch(`${API_BASE}/api/claim`, {
      method: "POST",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ campaign: "Flyer2026", turnstileToken }),
    });
  } catch {
    showError("Nätverksfel. Försök igen.");
    return;
  }

  if (res.status === 410) {
    showError("Alla koder är slut. Följ oss för nästa kampanj!");
    return;
  }
  if (res.status === 403) {
    showError("Säkerhetskontroll misslyckades. Ladda om sidan.");
    return;
  }
  if (res.status === 429) {
    showError("För många försök. Vänta en stund och försök igen.");
    return;
  }
  if (!res.ok) {
    showError("Tjänsten är inte tillgänglig just nu.");
    return;
  }

  const data = await res.json();
  if (data.status !== "ok" || !data.code) {
    showError("Kunde inte hämta en kod.");
    return;
  }

  try {
    localStorage.setItem(LOCAL_KEY, JSON.stringify({ code: data.code, url: data.redeem_url }));
  } catch { /* ignore quota */ }
  showCode(data.code, data.redeem_url, { repeat: Boolean(data.repeat) });
}

// Logga scan (oberoende av claim, body-lös POST)
fetch(`${API_BASE}/api/scan`, { method: "POST", credentials: "include" }).catch(() => {});

claimBtn.addEventListener("click", () => {
  claimBtn.disabled = true;
  claimBtn.textContent = "Hämtar…";
  claimCode().finally(() => {
    // Token är engångs — be Turnstile om en ny om vi behöver retry
    turnstileToken = null;
    if (window.turnstile) window.turnstile.reset();
  });
});

copyBtn.addEventListener("click", async () => {
  const value = codeText.textContent.trim();
  if (!value || value === "—") return;
  try {
    await navigator.clipboard.writeText(value);
    copyBtn.textContent = "Kopierat!";
    setTimeout(() => (copyBtn.textContent = "Kopiera"), 1800);
  } catch {
    copyBtn.textContent = "Kunde ej kopiera";
  }
});

// Visa direkt om en kod redan finns cachad lokalt (snabb återladdning)
try {
  const cached = JSON.parse(localStorage.getItem(LOCAL_KEY) || "null");
  if (cached?.code) showCode(cached.code, cached.url, { repeat: true });
} catch { /* ignore */ }
