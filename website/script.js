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
const cookiePolicyLink = document.querySelector("#cookie-policy-link");

const translations = {
  en: {
    languageLabel: "Language",
    navFeatures: "Features",
    navExperience: "Experience",
    navLaunch: "Launch",
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
      "The message should be obvious immediately: this is a unique product for a specific vehicle world.",
    experienceBody:
      "That is why the site now leans harder into identity, community, and specialization. The goal is not to feel broad. The goal is to feel exactly right for the people it is actually built for, especially those who drive, gather, and cruise as a convoy.",
    experienceListOneLabel: "Positioning",
    experienceListOneValue: "Built for the right niche",
    experienceListTwoLabel: "Vehicles",
    experienceListTwoValue: "Built for specific vehicle types",
    experienceListThreeLabel: "Convoy",
    experienceListThreeValue: "Designed for moving together",
    launchEyebrow: "Launch",
    launchTitle: "Join CruizX and drive with people who match your vehicle culture.",
    launchBody:
      "Get launch updates, convoy invites, and early access features made for your kind of driving.",
    launchPlatforms: "Coming soon on iOS & Android.",
    emailPlaceholder: "Your email",
    launchCta: "Get early access",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Privacy",
    footerCookies: "Cookies",
    footerTerms: "Terms",
    cookieTitle: "Cookies on CruizX",
    cookieBody:
      "We use cookies and similar storage to remember language, improve the website, and support core functionality.",
    cookieReadMore: "Read Cookie Policy",
    cookieNecessary: "Only necessary",
    cookieAccept: "Accept all",
  },
  sv: {
    languageLabel: "Språk",
    navFeatures: "Funktioner",
    navExperience: "Upplevelse",
    navLaunch: "Lansering",
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
    routeTitle: "Byggd för fordonen. Byggd för konvojen.",
    routeBody:
      "CruizX är designad efter beteendet, energin och behoven i denna scen, med starkare fokus på konvojflöde, liveöversikt och att röra sig tillsammans.",
    signalOneLabel: "Fordon",
    signalOneValue: "Specialbyggd",
    signalTwoLabel: "Konvoj",
    signalTwoValue: "Livekoordinering",
    signalThreeLabel: "Community",
    signalThreeValue: "Byggd för kulturen",
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
      "Budskapet ska vara tydligt direkt: detta är en unik produkt för en specifik fordonsvärld.",
    experienceBody:
      "Därför lutar sidan hårdare mot identitet, community och specialisering. Målet är inte att vara bred. Målet är att kännas helt rätt för dem den faktiskt är byggd för.",
    experienceListOneLabel: "Positionering",
    experienceListOneValue: "Byggd för rätt nisch",
    experienceListTwoLabel: "Fordon",
    experienceListTwoValue: "Byggd för specifika fordonstyper",
    experienceListThreeLabel: "Konvoj",
    experienceListThreeValue: "Designad för att röra sig tillsammans",
    launchEyebrow: "Lansering",
    launchTitle: "Gå med i CruizX och kör med personer som passar din fordonskultur.",
    launchBody:
      "Få lanseringsuppdateringar, konvojinbjudningar och tidig tillgång till funktioner byggda för din typ av körning.",
    launchPlatforms: "Släpps snart för iOS & Android.",
    emailPlaceholder: "Din e-post",
    launchCta: "Få tidig tillgång",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Integritet",
    footerCookies: "Cookies",
    footerTerms: "Villkor",
    cookieTitle: "Cookies på CruizX",
    cookieBody:
      "Vi använder cookies och liknande lagring för att komma ihåg språk, förbättra webbplatsen och stödja grundläggande funktioner.",
    cookieReadMore: "Läs Cookie Policy",
    cookieNecessary: "Endast nödvändiga",
    cookieAccept: "Acceptera alla",
  },
  nb: {
    languageLabel: "Sprak",
    navFeatures: "Funksjoner",
    navExperience: "Opplevelse",
    navLaunch: "Lansering",
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
      "Budskapet skal vaere tydelig med en gang: dette er et unikt produkt for en spesifikk bilverden.",
    experienceBody:
      "Derfor lener siden seg hardere mot identitet, community og spesialisering. Malet er ikke a virke bred. Malet er a treffe helt riktig for dem den faktisk er bygget for.",
    experienceListOneLabel: "Posisjonering",
    experienceListOneValue: "Bygget for riktig nisje",
    experienceListTwoLabel: "Kjoretoy",
    experienceListTwoValue: "Bygget for spesifikke kjoretoytyper",
    experienceListThreeLabel: "Konvoi",
    experienceListThreeValue: "Designet for a bevege seg sammen",
    launchEyebrow: "Lansering",
    launchTitle: "Vis umiddelbart at CruizX er bygget for disse kjoretoyene.",
    launchBody:
      "Siden skal tiltrekke riktige folk ved a vaere tydelig pa hvem den er for, hvorfor konvoi betyr noe og hvorfor CruizX skiller seg ut.",
    launchPlatforms: "Kommer snart for iOS og Android.",
    emailPlaceholder: "Din e-post",
    launchCta: "Bli med pa lanseringen",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Personvern",
    footerCookies: "Cookies",
    footerTerms: "Vilkår",
    cookieTitle: "Cookies på CruizX",
    cookieBody:
      "Vi bruker cookies og lignende lagring for å huske språk, forbedre nettsiden og støtte kjernefunksjoner.",
    cookieReadMore: "Les Cookie Policy",
    cookieNecessary: "Kun nødvendige",
    cookieAccept: "Godta alle",
  },
  da: {
    languageLabel: "Sprog",
    navFeatures: "Funktioner",
    navExperience: "Oplevelse",
    navLaunch: "Lancering",
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
      "Budskabet skal vaere tydeligt med det samme: dette er et unikt produkt til en specifik bilverden.",
    experienceBody:
      "Derfor laener siden sig mere ind i identitet, community og specialisering. Malet er ikke at virke bredt. Malet er at ramme helt rigtigt for dem den faktisk er bygget til.",
    experienceListOneLabel: "Positionering",
    experienceListOneValue: "Bygget til den rigtige niche",
    experienceListTwoLabel: "Koretojer",
    experienceListTwoValue: "Bygget til specifikke koretojstyper",
    experienceListThreeLabel: "Konvoj",
    experienceListThreeValue: "Designet til at bevaege sig sammen",
    launchEyebrow: "Lancering",
    launchTitle: "Vis med det samme at CruizX er bygget til disse koretojer.",
    launchBody:
      "Siden skal tiltraekke de rigtige mennesker ved at vaere tydelig om hvem den er til, hvorfor konvoj betyder noget, og hvorfor CruizX skiller sig ud.",
    launchPlatforms: "Kommer snart til iOS og Android.",
    emailPlaceholder: "Din e-mail",
    launchCta: "Join launch",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Privatliv",
    footerCookies: "Cookies",
    footerTerms: "Vilkår",
    cookieTitle: "Cookies på CruizX",
    cookieBody:
      "Vi bruger cookies og lignende lagring for at huske sprog, forbedre websitet og understøtte kernefunktioner.",
    cookieReadMore: "Læs Cookie Policy",
    cookieNecessary: "Kun nødvendige",
    cookieAccept: "Accepter alle",
  },
  fi: {
    languageLabel: "Kieli",
    navFeatures: "Ominaisuudet",
    navExperience: "Kokemus",
    navLaunch: "Julkaisu",
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
      "Viestin tulee olla heti selva: tama on ainutlaatuinen tuote tiettyyn ajoneuvomaailmaan.",
    experienceBody:
      "Siksi sivu nojaa vahvemmin identiteettiin, yhteisoon ja erikoistumiseen. Tavoite ei ole olla laaja. Tavoite on tuntua taysin oikealta niille, joille se on rakennettu.",
    experienceListOneLabel: "Positiointi",
    experienceListOneValue: "Rakennettu oikeaan nicheen",
    experienceListTwoLabel: "Ajoneuvot",
    experienceListTwoValue: "Rakennettu tietyille ajoneuvotyypeille",
    experienceListThreeLabel: "Konvoji",
    experienceListThreeValue: "Suunniteltu liikkumaan yhdessa",
    launchEyebrow: "Julkaisu",
    launchTitle: "Nayta heti, etta CruizX on rakennettu nille ajoneuvoille.",
    launchBody:
      "Sivun tulee houkutella oikeat ihmiset olemalla selkea kenelle se on, miksi konvojit ovat tarkeita ja miksi CruizX erottuu kaikesta muusta.",
    launchPlatforms: "Tulossa pian iOS:lle ja Androidille.",
    emailPlaceholder: "Sahkopostisi",
    launchCta: "Liity julkaisuun",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Tietosuoja",
    footerCookies: "Evasteet",
    footerTerms: "Ehdot",
    cookieTitle: "Evasteet CruizXissa",
    cookieBody:
      "Kaytamme evasteita ja vastaavaa tallennusta kielen muistamiseen, sivuston parantamiseen ja ydintoimintojen tukemiseen.",
    cookieReadMore: "Lue Cookie Policy",
    cookieNecessary: "Vain valttamattomat",
    cookieAccept: "Hyvaksy kaikki",
  },
  fr: {
    languageLabel: "Langue",
    navFeatures: "Fonctionnalites",
    navExperience: "Experience",
    navLaunch: "Lancement",
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
      "Le message doit etre evident immediatement: c est un produit unique pour un monde vehicule specifique.",
    experienceBody:
      "C est pourquoi le site s appuie plus fortement sur l identite, la communaute et la specialisation. L objectif n est pas d etre large. L objectif est d etre parfaitement juste pour ceux pour qui il est construit.",
    experienceListOneLabel: "Positionnement",
    experienceListOneValue: "Concu pour la bonne niche",
    experienceListTwoLabel: "Vehicules",
    experienceListTwoValue: "Concu pour des types de vehicules specifiques",
    experienceListThreeLabel: "Convoi",
    experienceListThreeValue: "Concu pour bouger ensemble",
    launchEyebrow: "Lancement",
    launchTitle: "Montrez tout de suite que CruizX est concu pour ces vehicules.",
    launchBody:
      "Le site doit attirer les bonnes personnes en etant clair sur qui il vise, pourquoi le convoi compte et pourquoi CruizX est different du reste.",
    launchPlatforms: "Bientot disponible sur iOS et Android.",
    emailPlaceholder: "Votre e-mail",
    launchCta: "Rejoindre le lancement",
    footerTagline: "Driven by the ride.",
    footerPrivacy: "Confidentialite",
    footerCookies: "Cookies",
    footerTerms: "Conditions",
    cookieTitle: "Cookies sur CruizX",
    cookieBody:
      "Nous utilisons des cookies et un stockage similaire pour memoriser la langue, ameliorer le site et assurer les fonctions essentielles.",
    cookieReadMore: "Lire la Cookie Policy",
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
  if (footerPrivacyLink) footerPrivacyLink.href = `./privacy.html${query}`;
  if (footerCookiesLink) footerCookiesLink.href = `./cookies.html${query}`;
  if (footerTermsLink) footerTermsLink.href = `./terms.html${query}`;
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
