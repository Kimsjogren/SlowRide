const STATUS_ENDPOINT = "https://api.cruizx.com/status";
const REFRESH_INTERVAL_MS = 60_000;

const text = {
  en: { language: "Language", home: "Home", features: "Features", experience: "Experience", support: "Support", download: "Download", eyebrow: "System status", title: "CruizX service status", intro: "Live availability for the website, routing service, and active map data.", overall: "Overall status", checking: "Checking services…", checkingShort: "Checking", refresh: "Check now", service: "Service", website: "CruizX website", operational: "Operational", websiteBody: "The public CruizX website is available.", routing: "Navigation API", routingBody: "Testing the live Valhalla routing service.", routingUp: "Valhalla is responding normally ({ms} ms).", routingDown: "The routing service is not responding.", data: "Data", maps: "Map coverage", mapsBody: "Checking the active map package.", mapsUp: "Active tileset loaded · Valhalla {version}", degraded: "Service disruption", allOperational: "All systems operational", coverageEyebrow: "Active coverage", coverageTitle: "Available map countries", sweden: "Sweden", norway: "Norway", denmark: "Denmark", finland: "Finland", france: "France", greatBritain: "Great Britain", spain: "Spain", lastChecked: "Last checked", autoRefresh: "Automatically refreshes every minute" },
  sv: { language: "Språk", home: "Hem", features: "Funktioner", experience: "Upplevelse", support: "Support", download: "Ladda ner", eyebrow: "Systemstatus", title: "Driftstatus för CruizX", intro: "Aktuell tillgänglighet för webbplatsen, navigationen och aktiv kartdata.", overall: "Övergripande status", checking: "Kontrollerar tjänster…", checkingShort: "Kontrollerar", refresh: "Kontrollera nu", service: "Tjänst", website: "CruizX webbplats", operational: "Fungerar", websiteBody: "Den publika CruizX-webbplatsen är tillgänglig.", routing: "Navigations-API", routingBody: "Testar Valhallas navigationstjänst.", routingUp: "Valhalla svarar normalt ({ms} ms).", routingDown: "Navigationstjänsten svarar inte.", data: "Data", maps: "Karttäckning", mapsBody: "Kontrollerar det aktiva kartpaketet.", mapsUp: "Aktivt kartpaket laddat · Valhalla {version}", degraded: "Driftstörning", allOperational: "Alla system fungerar", coverageEyebrow: "Aktiv täckning", coverageTitle: "Tillgängliga kartländer", sweden: "Sverige", norway: "Norge", denmark: "Danmark", finland: "Finland", france: "Frankrike", greatBritain: "Storbritannien", spain: "Spanien", lastChecked: "Senast kontrollerad", autoRefresh: "Uppdateras automatiskt varje minut" },
  nb: { language: "Språk", home: "Hjem", features: "Funksjoner", experience: "Opplevelse", support: "Support", download: "Last ned", eyebrow: "Systemstatus", title: "Driftsstatus for CruizX", intro: "Direkte tilgjengelighet for nettstedet, navigasjonen og aktive kartdata.", overall: "Samlet status", checking: "Kontrollerer tjenester…", checkingShort: "Kontrollerer", refresh: "Kontroller nå", service: "Tjeneste", website: "CruizX-nettsted", operational: "Operativ", websiteBody: "Det offentlige CruizX-nettstedet er tilgjengelig.", routing: "Navigasjons-API", routingBody: "Tester Valhalla-rutetjenesten.", routingUp: "Valhalla svarer normalt ({ms} ms).", routingDown: "Rutetjenesten svarer ikke.", data: "Data", maps: "Kartdekning", mapsBody: "Kontrollerer den aktive kartpakken.", mapsUp: "Aktivt kartsett lastet · Valhalla {version}", degraded: "Driftsforstyrrelse", allOperational: "Alle systemer er operative", coverageEyebrow: "Aktiv dekning", coverageTitle: "Tilgjengelige kartland", sweden: "Sverige", norway: "Norge", denmark: "Danmark", finland: "Finland", france: "Frankrike", greatBritain: "Storbritannia", spain: "Spania", lastChecked: "Sist kontrollert", autoRefresh: "Oppdateres automatisk hvert minutt" },
  da: { language: "Sprog", home: "Hjem", features: "Funktioner", experience: "Oplevelse", support: "Support", download: "Download", eyebrow: "Systemstatus", title: "Driftsstatus for CruizX", intro: "Aktuel tilgængelighed for webstedet, navigationen og aktive kortdata.", overall: "Samlet status", checking: "Kontrollerer tjenester…", checkingShort: "Kontrollerer", refresh: "Kontrollér nu", service: "Tjeneste", website: "CruizX-websted", operational: "Operationel", websiteBody: "Det offentlige CruizX-websted er tilgængeligt.", routing: "Navigations-API", routingBody: "Tester Valhalla-rutetjenesten.", routingUp: "Valhalla svarer normalt ({ms} ms).", routingDown: "Rutetjenesten svarer ikke.", data: "Data", maps: "Kortdækning", mapsBody: "Kontrollerer den aktive kortpakke.", mapsUp: "Aktivt kortsæt indlæst · Valhalla {version}", degraded: "Driftsforstyrrelse", allOperational: "Alle systemer fungerer", coverageEyebrow: "Aktiv dækning", coverageTitle: "Tilgængelige kortlande", sweden: "Sverige", norway: "Norge", denmark: "Danmark", finland: "Finland", france: "Frankrig", greatBritain: "Storbritannien", spain: "Spanien", lastChecked: "Senest kontrolleret", autoRefresh: "Opdateres automatisk hvert minut" },
  fi: { language: "Kieli", home: "Etusivu", features: "Ominaisuudet", experience: "Kokemus", support: "Tuki", download: "Lataa", eyebrow: "Järjestelmän tila", title: "CruizX-palveluiden tila", intro: "Verkkosivuston, navigoinnin ja kartta-aineiston reaaliaikainen saatavuus.", overall: "Kokonaistila", checking: "Tarkistetaan palveluita…", checkingShort: "Tarkistetaan", refresh: "Tarkista nyt", service: "Palvelu", website: "CruizX-verkkosivusto", operational: "Toiminnassa", websiteBody: "Julkinen CruizX-verkkosivusto on saatavilla.", routing: "Navigointi-API", routingBody: "Testataan Valhalla-reitityspalvelua.", routingUp: "Valhalla vastaa normaalisti ({ms} ms).", routingDown: "Reitityspalvelu ei vastaa.", data: "Data", maps: "Karttakattavuus", mapsBody: "Tarkistetaan aktiivista karttapakettia.", mapsUp: "Aktiivinen karttapaketti ladattu · Valhalla {version}", degraded: "Palveluhäiriö", allOperational: "Kaikki järjestelmät toimivat", coverageEyebrow: "Aktiivinen kattavuus", coverageTitle: "Saatavilla olevat karttamaat", sweden: "Ruotsi", norway: "Norja", denmark: "Tanska", finland: "Suomi", france: "Ranska", greatBritain: "Iso-Britannia", spain: "Espanja", lastChecked: "Viimeksi tarkistettu", autoRefresh: "Päivittyy automaattisesti minuutin välein" },
  fr: { language: "Langue", home: "Accueil", features: "Fonctionnalités", experience: "Expérience", support: "Assistance", download: "Télécharger", eyebrow: "État du système", title: "État des services CruizX", intro: "Disponibilité en direct du site, de la navigation et des données cartographiques.", overall: "État général", checking: "Vérification des services…", checkingShort: "Vérification", refresh: "Vérifier", service: "Service", website: "Site CruizX", operational: "Opérationnel", websiteBody: "Le site public CruizX est disponible.", routing: "API de navigation", routingBody: "Test du service de routage Valhalla.", routingUp: "Valhalla répond normalement ({ms} ms).", routingDown: "Le service de routage ne répond pas.", data: "Données", maps: "Couverture cartographique", mapsBody: "Vérification du pack cartographique actif.", mapsUp: "Jeu de cartes actif chargé · Valhalla {version}", degraded: "Perturbation du service", allOperational: "Tous les systèmes sont opérationnels", coverageEyebrow: "Couverture active", coverageTitle: "Pays cartographiques disponibles", sweden: "Suède", norway: "Norvège", denmark: "Danemark", finland: "Finlande", france: "France", greatBritain: "Grande-Bretagne", spain: "Espagne", lastChecked: "Dernière vérification", autoRefresh: "Actualisation automatique chaque minute" },
};

const languageSelect = document.querySelector("#status-language-select");
const overallCard = document.querySelector("#overall-card");
const overallIndicator = document.querySelector("#overall-indicator");
const overallText = document.querySelector("#overall-text");
const routingState = document.querySelector("#routing-state");
const routingDetail = document.querySelector("#routing-detail");
const mapsState = document.querySelector("#maps-state");
const mapsDetail = document.querySelector("#maps-detail");
const lastChecked = document.querySelector("#last-checked");
const refreshButton = document.querySelector("#status-refresh");

let activeLanguage = "en";
let latestStatus = null;

function translate(key, variables = {}) {
  let value = text[activeLanguage]?.[key] || text.en[key] || key;
  for (const [name, replacement] of Object.entries(variables)) {
    value = value.replace(`{${name}}`, replacement);
  }
  return value;
}

function applyLanguage(language) {
  activeLanguage = text[language] ? language : "en";
  document.documentElement.lang = activeLanguage;
  document.querySelectorAll("[data-status-i18n]").forEach((node) => {
    const key = node.dataset.statusI18n;
    if (text[activeLanguage][key]) node.textContent = text[activeLanguage][key];
  });
  languageSelect.value = activeLanguage;
  languageSelect.setAttribute("aria-label", translate("language"));
  localStorage.setItem("cruizx_site_lang", activeLanguage);
  renderStatus();
}

function setState(node, state, label) {
  node.classList.remove("is-up", "is-down", "is-checking");
  node.classList.add(`is-${state}`);
  if (label) node.textContent = label;
}

function renderStatus() {
  if (!latestStatus) return;
  const { ok, responseMs, version, checkedAt } = latestStatus;
  overallCard.classList.toggle("is-up", ok);
  overallCard.classList.toggle("is-down", !ok);
  setState(overallIndicator, ok ? "up" : "down");
  overallText.textContent = translate(ok ? "allOperational" : "degraded");
  setState(routingState, ok ? "up" : "down", translate(ok ? "operational" : "degraded"));
  routingDetail.textContent = ok ? translate("routingUp", { ms: responseMs }) : translate("routingDown");
  setState(mapsState, ok ? "up" : "down", translate(ok ? "operational" : "degraded"));
  mapsDetail.textContent = ok ? translate("mapsUp", { version }) : translate("routingDown");
  lastChecked.textContent = new Intl.DateTimeFormat(activeLanguage, {
    dateStyle: "medium",
    timeStyle: "medium",
  }).format(checkedAt);
}

async function checkStatus() {
  refreshButton.disabled = true;
  setState(overallIndicator, "checking");
  setState(routingState, "checking", translate("checkingShort"));
  setState(mapsState, "checking", translate("checkingShort"));
  overallText.textContent = translate("checking");
  const started = performance.now();

  try {
    const response = await fetch(`${STATUS_ENDPOINT}?t=${Date.now()}`, {
      cache: "no-store",
      signal: AbortSignal.timeout(10_000),
    });
    const data = await response.json();
    if (!response.ok || !data.version || !data.tileset_last_modified) throw new Error("Invalid status response");
    latestStatus = {
      ok: true,
      responseMs: Math.round(performance.now() - started),
      version: data.version,
      checkedAt: new Date(),
    };
  } catch (_) {
    latestStatus = {
      ok: false,
      responseMs: null,
      version: null,
      checkedAt: new Date(),
    };
  } finally {
    refreshButton.disabled = false;
    renderStatus();
  }
}

const savedLanguage = localStorage.getItem("cruizx_site_lang");
const browserLanguage = (navigator.language || "en").slice(0, 2).toLowerCase();
applyLanguage(savedLanguage || browserLanguage);
languageSelect.addEventListener("change", (event) => applyLanguage(event.target.value));
refreshButton.addEventListener("click", checkStatus);
checkStatus();
setInterval(checkStatus, REFRESH_INTERVAL_MS);
