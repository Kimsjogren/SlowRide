const revealItems = document.querySelectorAll(".reveal");
const yearNode = document.querySelector("#year");
const languageSelect = document.querySelector("#language-select");
const liveClockNode = document.querySelector(".screen-time");
const cookieBanner = document.querySelector("#cookie-banner");
const cookieAcceptBtn = document.querySelector("#cookie-accept");
const cookieNecessaryBtn = document.querySelector("#cookie-necessary");
const footerPrivacyLink = document.querySelector("#footer-privacy-link");
const footerCookiesLink = document.querySelector("#footer-cookies-link");
const footerTermsLink = document.querySelector("#footer-terms-link");
const footerSupportLink = document.querySelector("#footer-support-link");
const navSupportLink = document.querySelector("#nav-support-link");
const navDownloadLink = document.querySelector("#nav-download-link");
const downloadBackLink = document.querySelector("#download-back-link");
const cookiePolicyLink = document.querySelector("#cookie-policy-link");

const translations = {
  en: {
    languageLabel: "Language",
    navFeatures: "Features",
    navExperience: "Experience",
    navSupport: "Support",
    navDownload: "Download",
    supportEyebrow: "Support",
    supportTitle: "Need help with CruizX?",
    supportBody:
      "Get support with account questions, launch access, and app-related issues. We usually reply as quickly as possible.",
    supportMailLabel: "Email us directly:",
    downloadEyebrow: "Download",
    downloadTitle: "Get CruizX on iPhone",
    downloadBody:
      "Install CruizX via the App Store. If you open this page on your phone, tap the App Store badge to continue.",
    downloadAndroidNote:
      "Android APK — free version. Install manually (outside Google Play).",
    proTitle: "Upgrade to CruizX Pro",
    proBody: "Unlimited routes, enhanced convoy support and an ad-free experience.",
    proPrice: "39 kr / month",
    proCta: "Get Pro",
    proNote: "Secure payment via Stripe. Cancel anytime.",
    downloadBack: "← Back to CruizX",
    heroEyebrow: "For slow vehicles",
    heroTitle:
      "Built for slow vehicles: navigation, convoy, and live road alerts in one app.",
    heroBody:
      "CruizX is not another app trying to fit everyone. It is built for people who live in this vehicle culture and want an experience that actually understands how they drive, meet, communicate, and move together.",
    heroBodySecondary:
      "From the first meetup point to the last car in the line, CruizX is designed around convoy movement, shared presence, and the kind of driving culture generic map apps never get right.",
    heroPrimaryCta: "Get started",
    heroSecondaryCta: "See more",
    heroStatOneTitle: "Unique",
    heroStatOneBody: "built for a niche, not the mass market",
    heroStatTwoTitle: "Vehicles",
    heroStatTwoBody: "designed for this specific kind of driving",
    heroStatThreeTitle: "Convoy",
    heroStatThreeBody: "built around group movement and live coordination",
    screenPill: "CruizX live",
    routeLabel: "Convoy focused",
    routeTitle: "Built for the vehicles. Built for the convoy.",
    routeBody:
      "CruizX is designed around the behavior, energy, and needs of this scene, with a stronger focus on convoy flow, live group awareness, and moving together.",
    signalOneLabel: "Vehicles",
    signalOneValue: "Purpose-built",
    signalTwoLabel: "Convoy",
    signalTwoValue: "Live coordination",
    signalThreeLabel: "Community",
    signalThreeValue: "Built for the culture",
    stripOne: "Built for the scene",
    stripTwo: "Not for every vehicle",
    stripThree: "Convoy first",
    stripFour: "Live coordination",
    stripFive: "Community focused",
    featuresEyebrow: "Features",
    featuresTitle:
      "CruizX should feel obvious to the right drivers and clearly focused on the right audience.",
    featureOneTitle: "Built for the right kind of vehicles",
    featureOneBody:
      "The entire experience should signal that CruizX is not a general purpose app, but something made for this specific vehicle group.",
    featureTwoTitle: "Built around convoy behavior",
    featureTwoBody:
      "CruizX is shaped around how convoys actually move: staying connected, keeping formation, finding each other, and sharing live awareness on the road.",
    featureThreeTitle: "Built for convoy culture, not just utility",
    featureThreeBody:
      "CruizX does not just sell tools. It sells belonging, style, and the feeling that the product actually understands its users and the way they roll together.",
    experienceEyebrow: "Experience",
    experienceTitle:
      "CruizX is built for the right vehicles and the right way of driving.",
    experienceBody:
      "CruizX is not a generic app. It is built for drivers who move in convoy, want better live awareness, and need features adapted for this specific type of vehicle.",
    experienceListOneLabel: "Positioning",
    experienceListOneValue: "Right vehicles, right features",
    experienceListTwoLabel: "Vehicles",
    experienceListTwoValue: "Adapted for slow vehicles",
    experienceListThreeLabel: "Convoy",
    experienceListThreeValue: "Built for driving together",
    launchEyebrow: "Launch",
    launchTitle: "Join CruizX and get early access to features built for your driving style.",
    launchBody:
      "Get launch updates and early-access features built for your kind of driving.",
    launchPlatforms: "Also coming soon on Google Play.",
    emailPlaceholder: "Your email",
    launchCta: "Get early access",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Privacy",
    footerCookies: "Cookies",
    footerTerms: "Terms",
    footerSupport: "Support",
    cookieTitle: "Cookies on CruizX",
    cookieBody:
      "We use cookies and similar storage to remember language, improve the website, and support core functionality.",
    cookieReadMore: "Read cookie policy",
    cookieNecessary: "Only necessary",
    cookieAccept: "Accept all",
  },
  sv: {
    languageLabel: "Språk",
    navFeatures: "Funktioner",
    navExperience: "Upplevelse",
    navSupport: "Support",
    navDownload: "Ladda ner",
    supportEyebrow: "Support",
    supportTitle: "Behöver du hjälp med CruizX?",
    supportBody:
      "Få hjälp med kontofrågor, lanseringsåtkomst och apprelaterade problem. Vi svarar vanligtvis så snabbt som möjligt.",
    supportMailLabel: "Mejla oss direkt:",
    downloadEyebrow: "Ladda ner",
    downloadTitle: "Hämta CruizX till iPhone",
    downloadBody:
      "Installera CruizX via App Store. Om du öppnar sidan från mobilen kan du trycka direkt på App Store-badgen.",
    downloadAndroidNote:
      "Android APK — gratis version. Installeras manuellt (utanför Google Play).",
    proTitle: "Uppgradera till CruizX Pro",
    proBody: "Obegränsade rutter, utökad konvojfunktion och en reklamfri upplevelse.",
    proPrice: "39 kr / månad",
    proCta: "Skaffa Pro",
    proNote: "Säker betalning via Stripe. Avsluta när som helst.",
    downloadBack: "← Tillbaka till CruizX",
    heroEyebrow: "För långsamma fordon",
    heroTitle:
      "Byggd för långsamma fordon: navigation, konvoj och live vägvarningar i en app.",
    heroBody:
      "CruizX är inte en app för alla. Den är byggd för personer som lever i den här fordonskulturen och vill ha en upplevelse som förstår hur de kör, möts, kommunicerar och rör sig tillsammans.",
    heroBodySecondary:
      "Från första mötesplats till sista bilen i ledet är CruizX designad för konvojrörelse, gemensam närvaro och en körkultur som generiska kartappar inte förstår.",
    heroPrimaryCta: "Kom igång",
    heroSecondaryCta: "Se mer",
    heroStatOneTitle: "Unik",
    heroStatOneBody: "byggd för en nisch, inte massmarknad",
    heroStatTwoTitle: "Fordon",
    heroStatTwoBody: "designad för denna typ av körning",
    heroStatThreeTitle: "Konvoj",
    heroStatThreeBody: "byggd för grupprörelse och livekoordinering",
    screenPill: "CruizX live",
    routeLabel: "Konvojfokus",
    routeTitle: "Byggd för fordon. Byggd för konvoj.",
    routeBody:
      "CruizX är byggd för den här scenen, med fokus på konvojflöde, liveöversikt och att röra sig tillsammans.",
    signalOneLabel: "Fordon",
    signalOneValue: "Specialbyggd",
    signalTwoLabel: "Konvoj",
    signalTwoValue: "Live-koordinering",
    signalThreeLabel: "Community",
    signalThreeValue: "För kulturen",
    stripOne: "Byggd för scenen",
    stripTwo: "Inte för alla fordon",
    stripThree: "Konvoj först",
    stripFour: "Livekoordinering",
    stripFive: "Communityfokus",
    featuresEyebrow: "Funktioner",
    featuresTitle:
      "CruizX ska kännas självklar för rätt förare och tydligt fokuserad på rätt målgrupp.",
    featureOneTitle: "Byggd för rätt typ av fordon",
    featureOneBody:
      "Hela upplevelsen ska visa att CruizX inte är en allmän app, utan något byggt för denna specifika fordonsgrupp.",
    featureTwoTitle: "Byggd runt konvojbeteende",
    featureTwoBody:
      "CruizX är utformad efter hur konvojer faktiskt rör sig: hålla kontakt, hålla formation, hitta varandra och dela liveöversikt på vägen.",
    featureThreeTitle: "Byggd för konvojkultur, inte bara funktion",
    featureThreeBody:
      "CruizX säljer inte bara verktyg. Den säljer tillhörighet, stil och känslan av att produkten faktiskt förstår användarna.",
    experienceEyebrow: "Upplevelse",
    experienceTitle:
      "CruizX är byggd för rätt fordon och rätt sätt att köra.",
    experienceBody:
      "CruizX är inte en generell app. Den är byggd för dig som kör i konvoj, vill ha bättre överblick i realtid och funktioner anpassade för just den här typen av fordon.",
    experienceListOneLabel: "Positionering",
    experienceListOneValue: "Rätt fordon, rätt funktioner",
    experienceListTwoLabel: "Fordon",
    experienceListTwoValue: "Anpassad för långsamma fordon",
    experienceListThreeLabel: "Konvoj",
    experienceListThreeValue: "Byggd för att köra tillsammans",
    launchEyebrow: "Lansering",
    launchTitle: "Gå med i CruizX och få tidig tillgång till funktioner byggda för ditt sätt att köra.",
    launchBody:
      "Få lanseringsuppdateringar och tidig tillgång till funktioner anpassade för din typ av körning.",
    launchPlatforms: "Finns snart även på Google Play.",
    emailPlaceholder: "Din e-post",
    launchCta: "Få tidig tillgång",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Integritet",
    footerCookies: "Cookies",
    footerTerms: "Villkor",
    footerSupport: "Support",
    cookieTitle: "Cookies på CruizX",
    cookieBody:
      "Vi använder cookies och liknande lagring för att komma ihåg språk, förbättra webbplatsen och stödja grundläggande funktioner.",
    cookieReadMore: "Läs cookiepolicy",
    cookieNecessary: "Endast nödvändiga",
    cookieAccept: "Acceptera alla",
  },
  nb: {
    languageLabel: "Sprak",
    navFeatures: "Funksjoner",
    navExperience: "Opplevelse",
    navSupport: "Support",
    navDownload: "Last ned",
    supportEyebrow: "Support",
    supportTitle: "Trenger du hjelp med CruizX?",
    supportBody:
      "Fa hjelp med kontosporsmal, lanseringstilgang og apprelaterte problemer. Vi svarer vanligvis sa raskt som mulig.",
    supportMailLabel: "Send oss e-post direkte:",
    downloadEyebrow: "Last ned",
    downloadTitle: "Last ned CruizX til iPhone",
    downloadBody:
      "Installer CruizX via App Store. Hvis du åpner siden på mobilen, kan du trykke direkte på App Store-merket.",
    downloadAndroidNote:
      "Android APK – gratis versjon. Installeres manuelt (utenfor Google Play).",
    proTitle: "Oppgrader til CruizX Pro",
    proBody: "Ubegrensede ruter, forbedret konvoistøtte og en reklamefri opplevelse.",
    proPrice: "39 kr / måned",
    proCta: "Få Pro",
    proNote: "Sikker betaling via Stripe. Avslutt når som helst.",
    downloadBack: "← Tilbake til CruizX",
    heroEyebrow: "For langsomme kjoretoy",
    heroTitle:
      "Bygget for langsomme kjoretoy: navigasjon, konvoi og live veivarsler i en app.",
    heroBody:
      "CruizX er ikke en app for alle. Den er bygget for folk som lever i denne bilkulturen og vil ha en opplevelse som forstar hvordan de kjorer, motes, kommuniserer og beveger seg sammen.",
    heroBodySecondary:
      "Fra forste motepunkt til siste bil i rekken er CruizX designet rundt konvoibevegelse, delt tilstedevaerelse og en kjorekultur vanlige kartapper ikke forstar.",
    heroPrimaryCta: "Kom i gang",
    heroSecondaryCta: "Se mer",
    heroStatOneTitle: "Unik",
    heroStatOneBody: "bygget for en nisje, ikke massemarked",
    heroStatTwoTitle: "Kjoretoy",
    heroStatTwoBody: "designet for denne typen kjoring",
    heroStatThreeTitle: "Konvoi",
    heroStatThreeBody: "bygget rundt gruppebevegelse og livekoordinering",
    screenPill: "CruizX live",
    routeLabel: "Konvoifokus",
    routeTitle: "Bygget for kjoretoyene. Bygget for konvoien.",
    routeBody:
      "CruizX er designet rundt adferden, energien og behovene i dette miljot, med sterkere fokus pa konvoiflyt, liveoversikt og det a bevege seg sammen.",
    signalOneLabel: "Kjoretoy",
    signalOneValue: "Spesialbygget",
    signalTwoLabel: "Konvoi",
    signalTwoValue: "Livekoordinering",
    signalThreeLabel: "Community",
    signalThreeValue: "Bygget for kulturen",
    stripOne: "Bygget for miljot",
    stripTwo: "Ikke for alle kjoretoy",
    stripThree: "Konvoi forst",
    stripFour: "Livekoordinering",
    stripFive: "Communityfokus",
    featuresEyebrow: "Funksjoner",
    featuresTitle:
      "CruizX skal kjennes opplagt for riktige forere og tydelig fokusert pa riktig malgruppe.",
    featureOneTitle: "Bygget for riktig type kjoretoy",
    featureOneBody:
      "Hele opplevelsen skal vise at CruizX ikke er en generell app, men noe laget for denne spesifikke kjoretoygruppen.",
    featureTwoTitle: "Bygget rundt konvoiadferd",
    featureTwoBody:
      "CruizX er formet rundt hvordan konvoier faktisk beveger seg: holde kontakt, holde formasjon, finne hverandre og dele liveoversikt pa veien.",
    featureThreeTitle: "Bygget for konvoikultur, ikke bare nytte",
    featureThreeBody:
      "CruizX selger ikke bare verktoy. Den selger tilhorighet, stil og folelsen av at produktet faktisk forstar brukerne.",
    experienceEyebrow: "Opplevelse",
    experienceTitle:
      "CruizX er bygget for riktige kjoretoy og riktig mate a kjore pa.",
    experienceBody:
      "CruizX er ikke en generell app. Den er bygget for deg som kjorer i konvoi, vil ha bedre liveoversikt og funksjoner tilpasset denne typen kjoretoy.",
    experienceListOneLabel: "Posisjonering",
    experienceListOneValue: "Riktige kjoretoy, riktige funksjoner",
    experienceListTwoLabel: "Kjoretoy",
    experienceListTwoValue: "Tilpasset for langsomme kjoretoy",
    experienceListThreeLabel: "Konvoi",
    experienceListThreeValue: "Bygget for a kjore sammen",
    launchEyebrow: "Lansering",
    launchTitle: "Bli med i CruizX og få tidlig tilgang til funksjoner bygget for din kjørestil.",
    launchBody:
      "Få lanseringsoppdateringer og tidlig tilgang til funksjoner bygget for denne typen kjøring.",
    launchPlatforms: "Kommer snart på Google Play.",
    emailPlaceholder: "Din e-post",
    launchCta: "Få tidlig tilgang",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Personvern",
    footerCookies: "Cookies",
    footerTerms: "Vilkår",
    footerSupport: "Support",
    cookieTitle: "Cookies på CruizX",
    cookieBody:
      "Vi bruker cookies og lignende lagring for å huske språk, forbedre nettsiden og støtte kjernefunksjoner.",
    cookieReadMore: "Les cookiepolicy",
    cookieNecessary: "Kun nødvendige",
    cookieAccept: "Godta alle",
  },
  da: {
    languageLabel: "Sprog",
    navFeatures: "Funktioner",
    navExperience: "Oplevelse",
    navSupport: "Support",
    navDownload: "Download",
    supportEyebrow: "Support",
    supportTitle: "Har du brug for hjalp med CruizX?",
    supportBody:
      "Fa hjalp med kontosporgsmal, lanceringsadgang og apprelaterede problemer. Vi svarer som regel sa hurtigt som muligt.",
    supportMailLabel: "Send os en e-mail direkte:",
    downloadEyebrow: "Download",
    downloadTitle: "Hent CruizX til iPhone",
    downloadBody:
      "Installer CruizX via App Store. Hvis du åbner siden på mobilen, kan du trykke direkte på App Store-badget.",
    downloadAndroidNote:
      "Android APK – gratis version. Installeres manuelt (uden for Google Play).",
    proTitle: "Opgrader til CruizX Pro",
    proBody: "Ubegrænsede ruter, forbedret konvoistøtte og en reklamefri oplevelse.",
    proPrice: "39 kr / måned",
    proCta: "Få Pro",
    proNote: "Sikker betaling via Stripe. Annuller når som helst.",
    downloadBack: "← Tilbage til CruizX",
    heroEyebrow: "Til langsomme koretojer",
    heroTitle:
      "Bygget til langsomme koretojer: navigation, konvoj og live vejvarsler i en app.",
    heroBody:
      "CruizX er ikke en app til alle. Den er bygget til folk, der lever i denne bilkultur og vil have en oplevelse, som forstar hvordan de korer, modes, kommunikerer og bevaeger sig sammen.",
    heroBodySecondary:
      "Fra det forste modepunkt til den sidste bil i raekken er CruizX designet omkring konvojbevaegelse, faelles tilstedevaerelse og en korekultur som generiske kortapps ikke forstar.",
    heroPrimaryCta: "Kom i gang",
    heroSecondaryCta: "Se mere",
    heroStatOneTitle: "Unik",
    heroStatOneBody: "bygget til en niche, ikke massemarkedet",
    heroStatTwoTitle: "Koretojer",
    heroStatTwoBody: "designet til denne type koring",
    heroStatThreeTitle: "Konvoj",
    heroStatThreeBody: "bygget omkring gruppebevaegelse og livekoordinering",
    screenPill: "CruizX live",
    routeLabel: "Konvojfokus",
    routeTitle: "Bygget til koretojerne. Bygget til konvojen.",
    routeBody:
      "CruizX er designet omkring adfaerd, energi og behov i dette miljo, med storre fokus pa konvojflow, liveoverblik og at bevaege sig sammen.",
    signalOneLabel: "Koretojer",
    signalOneValue: "Specialbygget",
    signalTwoLabel: "Konvoj",
    signalTwoValue: "Livekoordinering",
    signalThreeLabel: "Community",
    signalThreeValue: "Bygget til kulturen",
    stripOne: "Bygget til scenen",
    stripTwo: "Ikke til alle koretojer",
    stripThree: "Konvoj forst",
    stripFour: "Livekoordinering",
    stripFive: "Communityfokus",
    featuresEyebrow: "Funktioner",
    featuresTitle:
      "CruizX skal foles oplagt for de rigtige forere og tydeligt fokuseret pa den rigtige malgruppe.",
    featureOneTitle: "Bygget til den rigtige type koretojer",
    featureOneBody:
      "Hele oplevelsen skal vise, at CruizX ikke er en generel app, men noget bygget til denne specifikke koretojsgruppe.",
    featureTwoTitle: "Bygget omkring konvojadfaerd",
    featureTwoBody:
      "CruizX er formet efter hvordan konvojer faktisk bevaeger sig: holde kontakt, holde formation, finde hinanden og dele liveoverblik pa vejen.",
    featureThreeTitle: "Bygget til konvojkultur, ikke kun nytte",
    featureThreeBody:
      "CruizX saelger ikke kun vaerktojer. Den saelger tilhor, stil og folsen af at produktet faktisk forstar brugerne.",
    experienceEyebrow: "Oplevelse",
    experienceTitle:
      "CruizX er bygget til de rigtige koretojer og den rigtige made at kore pa.",
    experienceBody:
      "CruizX er ikke en generel app. Den er bygget til dig, der korer i konvoj, vil have bedre liveoverblik og funktioner tilpasset denne type koretojer.",
    experienceListOneLabel: "Positionering",
    experienceListOneValue: "Rigtige koretojer, rigtige funktioner",
    experienceListTwoLabel: "Koretojer",
    experienceListTwoValue: "Tilpasset langsomme koretojer",
    experienceListThreeLabel: "Konvoj",
    experienceListThreeValue: "Bygget til at kore sammen",
    launchEyebrow: "Lancering",
    launchTitle: "Bliv en del af CruizX og få tidlig adgang til funktioner bygget til din kørestil.",
    launchBody:
      "Få lanceringsopdateringer og tidlig adgang til funktioner bygget til denne type kørsel.",
    launchPlatforms: "Kommer snart på Google Play.",
    emailPlaceholder: "Din e-mail",
    launchCta: "Få tidlig adgang",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Privatliv",
    footerCookies: "Cookies",
    footerTerms: "Vilkår",
    footerSupport: "Support",
    cookieTitle: "Cookies på CruizX",
    cookieBody:
      "Vi bruger cookies og lignende lagring for at huske sprog, forbedre websitet og understøtte kernefunktioner.",
    cookieReadMore: "Læs cookiepolitik",
    cookieNecessary: "Kun nødvendige",
    cookieAccept: "Accepter alle",
  },
  fi: {
    languageLabel: "Kieli",
    navFeatures: "Ominaisuudet",
    navExperience: "Kokemus",
    navSupport: "Tuki",
    navDownload: "Lataa",
    supportEyebrow: "Tuki",
    supportTitle: "Tarvitsetko apua CruizXin kanssa?",
    supportBody:
      "Saat apua tilikysymyksiin, julkaisuoikeuteen ja sovellukseen liittyviin ongelmiin. Vastaamme yleensa mahdollisimman nopeasti.",
    supportMailLabel: "Laheta meille suoraan sahkopostia:",
    downloadEyebrow: "Lataa",
    downloadTitle: "Hae CruizX iPhoneen",
    downloadBody:
      "Asenna CruizX App Storesta. Jos avaat sivun puhelimella, voit napauttaa suoraan App Store -merkkiä.",
    downloadAndroidNote:
      "Android APK – ilmainen versio. Asenna manuaalisesti (Google Playn ulkopuolelta).",
    proTitle: "Päivitä CruizX Prohon",
    proBody: "Rajattomat reitit, parannettu saattue-tuki ja mainokseton kokemus.",
    proPrice: "39 kr / kuukausi",
    proCta: "Hanki Pro",
    proNote: "Turvallinen maksu Stripen kautta. Peruuta milloin tahansa.",
    downloadBack: "← Takaisin CruizXiin",
    heroEyebrow: "Hitaille ajoneuvoille",
    heroTitle:
      "Rakennettu hitaille ajoneuvoille: navigointi, konvoji ja live tievaroitukset samassa sovelluksessa.",
    heroBody:
      "CruizX ei ole sovellus kaikille. Se on rakennettu ihmisille, jotka elavat tassa ajoneuvokulttuurissa ja haluavat kokemuksen, joka ymmartaa miten he ajavat, kohtaavat, viestivat ja liikkuvat yhdessa.",
    heroBodySecondary:
      "Ensimmisesta kohtaamispisteesta viimeiseen autoon asti CruizX on suunniteltu konvojiliikkeeseen, yhteiseen lasnaoloon ja ajokulttuuriin, jota yleiset karttasovellukset eivat ymmarra.",
    heroPrimaryCta: "Aloita",
    heroSecondaryCta: "Lue lisaa",
    heroStatOneTitle: "Ainutlaatuinen",
    heroStatOneBody: "rakennettu nichelle, ei massamarkkinaan",
    heroStatTwoTitle: "Ajoneuvot",
    heroStatTwoBody: "suunniteltu juuri tahan ajotyyliin",
    heroStatThreeTitle: "Konvoji",
    heroStatThreeBody: "rakennettu ryhmaliikkeeseen ja livekoordinointiin",
    screenPill: "CruizX live",
    routeLabel: "Konvojifokus",
    routeTitle: "Rakennettu ajoneuvoille. Rakennettu konvojille.",
    routeBody:
      "CruizX on suunniteltu taman skenen kayttaytymisen, energian ja tarpeiden mukaan, painottaen konvojin virtausta, live-tilannekuvaa ja yhdessa liikkumista.",
    signalOneLabel: "Ajoneuvot",
    signalOneValue: "Tarkoitukseen rakennettu",
    signalTwoLabel: "Konvoji",
    signalTwoValue: "Livekoordinointi",
    signalThreeLabel: "Yhteiso",
    signalThreeValue: "Rakennettu kulttuurille",
    stripOne: "Rakennettu skenelle",
    stripTwo: "Ei kaikille ajoneuvoille",
    stripThree: "Konvoji ensin",
    stripFour: "Livekoordinointi",
    stripFive: "Yhteisokeskeinen",
    featuresEyebrow: "Ominaisuudet",
    featuresTitle:
      "CruizXin pitaisi tuntua oikeille kuljettajille ilmeiselta ja selkeasti oikeaan kohderyhmaan kohdistetulta.",
    featureOneTitle: "Rakennettu oikealle ajoneuvoluokalle",
    featureOneBody:
      "Koko kokemuksen pitaisi viestia, etta CruizX ei ole yleissovellus vaan taman tietyn ajoneuvoryhman ratkaisu.",
    featureTwoTitle: "Rakennettu konvojikayttaytymisen ymparille",
    featureTwoBody:
      "CruizX on muotoiltu sen mukaan miten konvojit oikeasti liikkuvat: pysy yhteydessa, pida muodostelma, loyda toisensa ja jaa live-tilannekuvaa.",
    featureThreeTitle: "Rakennettu konvojikulttuurille, ei vain utiliteetille",
    featureThreeBody:
      "CruizX ei myy vain tyokaluja. Se myy yhteenkuuluvuutta, tyyli ja tunnetta siita, etta tuote ymmartaa kayttajansa.",
    experienceEyebrow: "Kokemus",
    experienceTitle:
      "CruizX on rakennettu oikeille ajoneuvoille ja oikeaan ajotapaan.",
    experienceBody:
      "CruizX ei ole yleissovellus. Se on rakennettu sinulle, joka ajat konvojissa, haluat paremman live-tilannekuvan ja ominaisuuksia juuri taman tyyppisille ajoneuvoille.",
    experienceListOneLabel: "Positiointi",
    experienceListOneValue: "Oikeat ajoneuvot, oikeat ominaisuudet",
    experienceListTwoLabel: "Ajoneuvot",
    experienceListTwoValue: "Sovitettu hitaille ajoneuvoille",
    experienceListThreeLabel: "Konvoji",
    experienceListThreeValue: "Rakennettu ajamaan yhdessa",
    launchEyebrow: "Julkaisu",
    launchTitle: "Liity CruizXiin ja saat varhaisen paasyn ominaisuuksiin, jotka sopivat ajotyyliisi.",
    launchBody:
      "Saat julkaisu-uutiset ja varhaisen paasyn ominaisuuksiin, jotka on rakennettu taman tyyppiseen ajoon.",
    launchPlatforms: "Tulossa pian myös Google Playhin.",
    emailPlaceholder: "Sahkopostisi",
    launchCta: "Liity julkaisuun",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Tietosuoja",
    footerCookies: "Evasteet",
    footerTerms: "Ehdot",
    footerSupport: "Tuki",
    cookieTitle: "Evasteet CruizXissa",
    cookieBody:
      "Kaytamme evasteita ja vastaavaa tallennusta kielen muistamiseen, sivuston parantamiseen ja ydintoimintojen tukemiseen.",
    cookieReadMore: "Lue evästekäytäntö",
    cookieNecessary: "Vain valttamattomat",
    cookieAccept: "Hyvaksy kaikki",
  },
  fr: {
    languageLabel: "Langue",
    navFeatures: "Fonctionnalites",
    navExperience: "Experience",
    navSupport: "Support",
    navDownload: "Telecharger",
    supportEyebrow: "Support",
    supportTitle: "Besoin d aide avec CruizX ?",
    supportBody:
      "Obtenez de l aide pour le compte, l acces au lancement et les problemes lies a l application. Nous repondons en general le plus vite possible.",
    supportMailLabel: "Envoyez-nous un e-mail directement :",
    downloadEyebrow: "Telecharger",
    downloadTitle: "Telechargez CruizX sur iPhone",
    downloadBody:
      "Installez CruizX via l App Store. Si vous ouvrez cette page sur mobile, appuyez directement sur le badge App Store.",
    downloadAndroidNote:
      "APK Android – version gratuite. Installation manuelle (hors Google Play).",
    proTitle: "Passer à CruizX Pro",
    proBody: "Itinéraires illimités, convoi amélioré et expérience sans publicité.",
    proPrice: "39 kr / mois",
    proCta: "Obtenir Pro",
    proNote: "Paiement sécurisé via Stripe. Annulez à tout moment.",
    downloadBack: "← Retour a CruizX",
    heroEyebrow: "Pour les vehicules lents",
    heroTitle:
      "Concu pour les vehicules lents: navigation, convoi et alertes route en direct dans une seule application.",
    heroBody:
      "CruizX n est pas une application pour tout le monde. Elle est concue pour les personnes qui vivent cette culture auto et veulent une experience qui comprend vraiment comment elles roulent, se retrouvent, communiquent et se deplacent ensemble.",
    heroBodySecondary:
      "Du premier point de rendez-vous a la derniere voiture de la file, CruizX est concu autour du mouvement en convoi, de la presence partagee et d une culture de conduite que les applis de carte generiques ne comprennent pas.",
    heroPrimaryCta: "Commencer",
    heroSecondaryCta: "Voir plus",
    heroStatOneTitle: "Unique",
    heroStatOneBody: "concu pour une niche, pas pour le marche de masse",
    heroStatTwoTitle: "Vehicules",
    heroStatTwoBody: "concu pour ce type de conduite specifique",
    heroStatThreeTitle: "Convoi",
    heroStatThreeBody: "concu pour le mouvement de groupe et la coordination live",
    screenPill: "CruizX live",
    routeLabel: "Focus convoi",
    routeTitle: "Concu pour les vehicules. Concu pour le convoi.",
    routeBody:
      "CruizX est concu autour du comportement, de l energie et des besoins de cette scene, avec un focus plus fort sur le flux de convoi, la vision live du groupe et le fait de bouger ensemble.",
    signalOneLabel: "Vehicules",
    signalOneValue: "Concu sur mesure",
    signalTwoLabel: "Convoi",
    signalTwoValue: "Coordination live",
    signalThreeLabel: "Communaute",
    signalThreeValue: "Concu pour la culture",
    stripOne: "Concu pour la scene",
    stripTwo: "Pas pour tous les vehicules",
    stripThree: "Convoi d abord",
    stripFour: "Coordination live",
    stripFive: "Focus communaute",
    featuresEyebrow: "Fonctionnalites",
    featuresTitle:
      "CruizX doit sembler evident pour les bons conducteurs et clairement axe sur le bon public.",
    featureOneTitle: "Concu pour le bon type de vehicules",
    featureOneBody:
      "Toute l experience doit montrer que CruizX n est pas une application generaliste, mais quelque chose concu pour ce groupe de vehicules specifique.",
    featureTwoTitle: "Concu autour du comportement en convoi",
    featureTwoBody:
      "CruizX est faconne selon la facon dont les convois se deplacent vraiment: rester connectes, garder la formation, se retrouver et partager une vision live de la route.",
    featureThreeTitle: "Concu pour la culture convoi, pas seulement l utilite",
    featureThreeBody:
      "CruizX ne vend pas seulement des outils. Il vend l appartenance, le style et le sentiment que le produit comprend vraiment ses utilisateurs.",
    experienceEyebrow: "Experience",
    experienceTitle:
      "CruizX est concu pour les bons vehicules et la bonne facon de rouler.",
    experienceBody:
      "CruizX n est pas une application generaliste. Elle est concue pour ceux qui roulent en convoi, veulent une meilleure vision live et des fonctions adaptees a ce type de vehicules.",
    experienceListOneLabel: "Positionnement",
    experienceListOneValue: "Bons vehicules, bonnes fonctions",
    experienceListTwoLabel: "Vehicules",
    experienceListTwoValue: "Adapte aux vehicules lents",
    experienceListThreeLabel: "Convoi",
    experienceListThreeValue: "Concu pour rouler ensemble",
    launchEyebrow: "Lancement",
    launchTitle: "Rejoignez CruizX et obtenez un acces anticipe aux fonctions adaptees a votre conduite.",
    launchBody:
      "Recevez les mises a jour de lancement et un acces anticipe aux fonctions adaptees a votre type de conduite.",
    launchPlatforms: "Bientot aussi sur Google Play.",
    emailPlaceholder: "Votre e-mail",
    launchCta: "Rejoindre le lancement",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Confidentialite",
    footerCookies: "Cookies",
    footerTerms: "Conditions",
    footerSupport: "Support",
    cookieTitle: "Cookies sur CruizX",
    cookieBody:
      "Nous utilisons des cookies et un stockage similaire pour memoriser la langue, ameliorer le site et assurer les fonctions essentielles.",
    cookieReadMore: "Lire la politique des cookies",
    cookieNecessary: "Seulement necessaires",
    cookieAccept: "Tout accepter",
  },
};

const supportedLanguages = ["da", "en", "fi", "fr", "nb", "sv"];
const COOKIE_CONSENT_KEY = "cruizx_cookie_consent";

function applyLanguage(lang) {
  const activeLang = supportedLanguages.includes(lang) ? lang : "en";
  const localeText = translations[activeLang] ?? translations.en;
  const fallbackText = translations.en;

  document.documentElement.lang = activeLang;

  document.querySelectorAll("[data-i18n]").forEach((node) => {
    const key = node.getAttribute("data-i18n");
    const value = localeText[key] ?? fallbackText[key];
    if (value) node.textContent = value;
  });

  document.querySelectorAll("[data-i18n-placeholder]").forEach((node) => {
    const key = node.getAttribute("data-i18n-placeholder");
    const value = localeText[key] ?? fallbackText[key];
    if (value) node.setAttribute("placeholder", value);
  });

  document.querySelectorAll("[data-i18n-aria-label]").forEach((node) => {
    const key = node.getAttribute("data-i18n-aria-label");
    const value = localeText[key] ?? fallbackText[key];
    if (value) node.setAttribute("aria-label", value);
  });

  if (languageSelect) languageSelect.value = activeLang;
  localStorage.setItem("cruizx_site_lang", activeLang);
  updateLegalLinks(activeLang);
}

function updateLegalLinks(lang) {
  const query = `?lang=${lang}`;
  const pathname = globalThis.location.pathname.toLowerCase();
  const isIndexPage = pathname.endsWith("/") || pathname.endsWith("/index.html");
  if (footerPrivacyLink) footerPrivacyLink.href = `./privacy.html${query}`;
  if (footerCookiesLink) footerCookiesLink.href = `./cookies.html${query}`;
  if (footerTermsLink) footerTermsLink.href = `./terms.html${query}`;
  if (footerSupportLink) {
    footerSupportLink.href = isIndexPage
      ? "#support"
      : `./index.html${query}#support`;
  }
  if (navSupportLink) {
    navSupportLink.href = isIndexPage
      ? "#support"
      : `./index.html${query}#support`;
  }
  if (navDownloadLink) {
    navDownloadLink.href = isIndexPage
      ? "#download"
      : `./index.html${query}#download`;
  }
  if (downloadBackLink) downloadBackLink.href = `./index.html${query}`;
  if (cookiePolicyLink) cookiePolicyLink.href = `./cookies.html${query}`;
}

if (yearNode) {
  yearNode.textContent = new Date().getFullYear();
}

function renderLiveClock() {
  if (!liveClockNode) return;
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, "0");
  const mm = String(now.getMinutes()).padStart(2, "0");
  liveClockNode.textContent = `${hh}:${mm}`;
}

renderLiveClock();
setInterval(renderLiveClock, 60 * 1000);

setInterval(renderLiveClock, 60 * 1000);

// ── Pro checkout ────────────────────────────────────────────────────────────
const btnBuyPro = document.querySelector("#btn-buy-pro");
if (btnBuyPro) {
  btnBuyPro.addEventListener("click", async () => {
    btnBuyPro.disabled = true;
    btnBuyPro.textContent = "…";
    try {
      const res = await fetch("https://cruizx.com/api/web/checkout-session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ uid: "", email: "" }),
      });
      const data = await res.json();
      if (data.url) {
        globalThis.location.href = data.url;
      } else {
        throw new Error(data.error || "no url");
      }
    } catch (_) {
      btnBuyPro.disabled = false;
      const lang = localStorage.getItem("cruizx_site_lang") || "en";
      btnBuyPro.textContent = translations[lang]?.proCta ?? "Get Pro";
      alert("Something went wrong. Please try again.");
    }
  });
}
// ────────────────────────────────────────────────────────────────────────────

const saved = localStorage.getItem("cruizx_site_lang");
const browserLang = (navigator.language || "en").slice(0, 2).toLowerCase();
const initial = supportedLanguages.includes(saved)
  ? saved
  : supportedLanguages.includes(browserLang)
    ? browserLang
    : "en";
applyLanguage(initial);

if (languageSelect) {
  languageSelect.addEventListener("change", (event) => {
    applyLanguage(event.target.value);
  });
}

function hideCookieBanner() {
  if (cookieBanner) cookieBanner.classList.add("hidden");
}

function saveCookieConsent(value) {
  localStorage.setItem(COOKIE_CONSENT_KEY, value);
  globalThis.dispatchEvent(
    new CustomEvent("cruizx:cookie-consent", { detail: { value } })
  );
  hideCookieBanner();
}

const savedCookieConsent = localStorage.getItem(COOKIE_CONSENT_KEY);
if (savedCookieConsent === "all" || savedCookieConsent === "necessary") {
  hideCookieBanner();
}

if (cookieAcceptBtn) {
  cookieAcceptBtn.addEventListener("click", () => {
    saveCookieConsent("all");
  });
}

if (cookieNecessaryBtn) {
  cookieNecessaryBtn.addEventListener("click", () => {
    saveCookieConsent("necessary");
  });
}

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
      }
    });
  },
  { threshold: 0.2 }
);

revealItems.forEach((item, index) => {
  item.style.transitionDelay = `${index * 70}ms`;
  observer.observe(item);
});
