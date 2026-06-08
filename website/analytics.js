const GA_MEASUREMENT_ID = "G-3P9ZKK0EK3";
const COOKIE_CONSENT_KEY = "cruizx_cookie_consent";
const ANALYTICS_LOADED_KEY = "cruizx_analytics_loaded";

function hasAnalyticsConsent() {
  try {
    return localStorage.getItem(COOKIE_CONSENT_KEY) === "all";
  } catch {
    return false;
  }
}

function loadGoogleAnalytics() {
  if (!GA_MEASUREMENT_ID || GA_MEASUREMENT_ID === "G-XXXXXXXXXX") return;
  if (window[ANALYTICS_LOADED_KEY]) return;
  if (!hasAnalyticsConsent()) return;

  window[ANALYTICS_LOADED_KEY] = true;
  window.dataLayer = window.dataLayer || [];
  window.gtag = function gtag() {
    window.dataLayer.push(arguments);
  };

  window.gtag("js", new Date());
  window.gtag("config", GA_MEASUREMENT_ID, {
    anonymize_ip: true,
    cookie_flags: "SameSite=Lax;Secure",
  });

  const script = document.createElement("script");
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(GA_MEASUREMENT_ID)}`;
  document.head.appendChild(script);
}

loadGoogleAnalytics();
window.addEventListener("cruizx:cookie-consent", loadGoogleAnalytics);
