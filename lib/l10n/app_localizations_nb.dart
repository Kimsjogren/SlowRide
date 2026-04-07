// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian Bokmål (`nb`).
class AppLocalizationsNb extends AppLocalizations {
  AppLocalizationsNb([String locale = 'nb']) : super(locale);

  @override
  String get appTitle => 'CruizX';

  @override
  String get navMap => 'Kart';

  @override
  String get navAlerts => 'Varsler';

  @override
  String get navConvoy => 'Kolonne';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSettings => 'Innstillinger';

  @override
  String get splashPreparingStartup => 'Forbereder oppstart...';

  @override
  String get splashLoadingCoreModules => 'Laster kjernemoduler...';

  @override
  String get splashInitializingAccountSession => 'Initialiserer kontoøkt...';

  @override
  String get splashLoadingPreferences => 'Laster innstillinger...';

  @override
  String get splashFinalizingStartup => 'Fullfører oppstart...';

  @override
  String get splashReady => 'Klar';

  @override
  String get splashVersionLine => 'v1.0.0 | CruizX by KimTechTool';

  @override
  String get alertsTitle => 'Fellesskapsvarsler';

  @override
  String get alertsSubtitle => 'Rapporter og se veifarer, kontroller og veiforhold.';

  @override
  String get convoyRequiresSignInTitle => 'Kolonne krever innlogging';

  @override
  String get convoyRequiresSignInSubtitle => 'Logg inn eller opprett en konto for å opprette kolonnegrupper og se direkteposisjoner.';

  @override
  String get signIn => 'Logg inn';

  @override
  String get signUp => 'Opprett konto';

  @override
  String get signOut => 'Logg ut';

  @override
  String get signInEmailDialogTitle => 'Logg inn med e-post OTP';

  @override
  String get signUpEmailDialogTitle => 'Opprett konto med e-post OTP';

  @override
  String get signInEmailFieldLabel => 'E-post';

  @override
  String get signInEmailHint => 'navn@eksempel.no';

  @override
  String get signInSendOtp => 'Send kode';

  @override
  String get signUpSendOtp => 'Send kontokode';

  @override
  String get signInOtpFieldLabel => 'OTP-kode';

  @override
  String get signInOtpHint => '6-sifret kode';

  @override
  String get signInVerifyOtp => 'Bekreft kode';

  @override
  String get signInOtpSent => 'OTP-kode sendt til e-posten din.';

  @override
  String get signUpOtpSent => 'Kontoopprettingskode sendt til e-posten din.';

  @override
  String get signInOtpInvalid => 'Kunne ikke bekrefte OTP. Sjekk koden og prøv igjen.';

  @override
  String get signUpNoAccountAction => 'Ingen konto? Opprett en';

  @override
  String get signUpHaveAccountAction => 'Har du allerede en konto? Logg inn';

  @override
  String get authGenericError => 'Noe gikk galt. Prøv igjen.';

  @override
  String get authWelcomeBack => 'Velkommen tilbake til CruizX';

  @override
  String get authRegisterSubtitle => 'Bli med i CruizX-fellesskapet';

  @override
  String get authEmailLabel => 'E-postadresse';

  @override
  String get authEmailRequired => 'Skriv inn e-postadressen din';

  @override
  String get authEmailInvalid => 'Ugyldig e-post';

  @override
  String get authPasswordLabel => 'Passord';

  @override
  String get authPasswordRequired => 'Skriv inn passordet ditt';

  @override
  String get authPasswordMinLength => 'Minst 6 tegn';

  @override
  String get authConfirmPasswordLabel => 'Bekreft passord';

  @override
  String get authConfirmPasswordRequired => 'Bekreft passordet ditt';

  @override
  String get authPasswordsDoNotMatch => 'Passordene stemmer ikke overens.';

  @override
  String get authDisplayNameLabel => 'Visningsnavn';

  @override
  String get authDisplayNameRequired => 'Skriv inn navnet ditt';

  @override
  String get authNoAccountPrompt => 'Ingen konto? ';

  @override
  String get authAlreadyHaveAccountPrompt => 'Har du allerede en konto? ';

  @override
  String get authCancel => 'Avbryt';

  @override
  String get authForgotPasswordLink => 'Glemt passord?';

  @override
  String get authForgotPasswordTitle => 'Tilbakestill passord';

  @override
  String get authForgotPasswordDescription => 'Skriv inn e-postadressen din, så sender vi deg en lenke for å tilbakestille passordet.';

  @override
  String get authForgotPasswordButton => 'Send tilbakestillingslenke';

  @override
  String get authForgotPasswordSuccess => 'Hvis kontoen finnes, har vi sendt en tilbakestillingslenke til e-posten din.';

  @override
  String get authResetPasswordTitle => 'Nytt passord';

  @override
  String get authResetPasswordDescription => 'Skriv inn ditt nye passord nedenfor.';

  @override
  String get authNewPasswordLabel => 'Nytt passord';

  @override
  String get authResetPasswordButton => 'Lagre passord';

  @override
  String get authResetPasswordSuccess => 'Passordet ditt har blitt endret.';

  @override
  String get authErrorAllFieldsRequired => 'Alle felt er påkrevd.';

  @override
  String get authErrorPasswordTooShort => 'Passordet må være minst 6 tegn.';

  @override
  String get authErrorConfirmEmail => 'Sjekk e-posten din for å bekrefte kontoen, deretter logg inn.';

  @override
  String get authErrorEmailAndPasswordRequired => 'Skriv inn e-post og passord.';

  @override
  String get authErrorInvalidCredentials => 'Feil e-post eller passord.';

  @override
  String get authErrorEmailAlreadyInUse => 'Det finnes allerede en konto med den e-postadressen.';

  @override
  String get convoyRealtimeBackendMissing => 'Sanntidskolonne er ikke konfigurert ennå. Legg til backend-konfigurasjon for å dele direkteposisjon mellom brukere.';

  @override
  String get convoyModeTitle => 'Kolonnemodus';

  @override
  String get convoyModeSubtitle => 'Opprett gruppekjøring med delt destinasjon og direkteposisjoner.';

  @override
  String get convoyCreateButton => 'Opprett kolonne';

  @override
  String get convoyOpenButton => 'Åpne';

  @override
  String get convoyJoinButton => 'Bli med';

  @override
  String get convoyLeaveButton => 'Forlat';

  @override
  String get convoyJoinFirstHint => 'Bli med i kolonnen først, trykk deretter for å åpne chat og kart.';

  @override
  String get convoyJoinByCodeTitle => 'Bli med i kolonne';

  @override
  String get convoyJoinByCodeHint => 'Skriv inn kolonnekoden du har mottatt';

  @override
  String get convoyJoinWithCodeButton => 'Bli med';

  @override
  String get convoyJoinByCodeNotFound => 'Ingen kolonne funnet med den koden.';

  @override
  String convoyJoinByCodeSuccess(String name) {
    return 'Du ble med i $name!';
  }

  @override
  String get convoyInviteButton => 'Inviter';

  @override
  String get convoyTabMap => 'Kart';

  @override
  String get convoyTabChat => 'Chat';

  @override
  String get convoyMapHint => 'Trykk på kartet for å plassere en delt markør.';

  @override
  String get convoyRecenterTooltip => 'Sentrer og følg posisjonen min';

  @override
  String get convoyPinDialogTitle => 'Legg til kartmarkør';

  @override
  String get convoyPinLabel => 'Markørnavn';

  @override
  String get convoyPinHint => 'f.eks. Møt oss her';

  @override
  String get convoyPinAdd => 'Legg til markør';

  @override
  String get convoyHazardPolice => 'Politi';

  @override
  String get convoyHazardRoadwork => 'Veiarbeid';

  @override
  String get convoyHazardAccident => 'Ulykke';

  @override
  String get convoyHazardTrafficJam => 'Kø';

  @override
  String get convoyHazardSpeedCamera => 'Fotoboks';

  @override
  String get convoyHazardCustom => 'Egendefinert markør';

  @override
  String get convoyChatEmpty => 'Ingen meldinger ennå.';

  @override
  String get convoyChatPlaceholder => 'Skriv en melding...';

  @override
  String get convoyChatSend => 'Send';

  @override
  String get convoyNameDialogTitle => 'Opprett kolonne';

  @override
  String get convoyNameFieldLabel => 'Kolonnenavn';

  @override
  String get convoyNameHint => 'f.eks. Fredagskjøring';

  @override
  String get convoyCreateConfirm => 'Opprett';

  @override
  String get convoyCreateCancel => 'Avbryt';

  @override
  String get convoyListEmpty => 'Ingen kolonner ennå. Opprett den første.';

  @override
  String get convoyListEmptyMine => 'Du har ikke blitt med i noen kolonner ennå.';

  @override
  String get convoyFilterAll => 'Alle';

  @override
  String get convoyFilterMine => 'Mine';

  @override
  String convoyMembers(Object count) {
    return '$count medlemmer';
  }

  @override
  String get convoyMemberMe => 'Meg';

  @override
  String convoyMemberStaleTime(Object mins) {
    return '${mins}m siden';
  }

  @override
  String convoyCreatedBy(Object leader) {
    return 'Opprettet av $leader';
  }

  @override
  String get profileTitle => 'Profil & Statistikk';

  @override
  String get profileNotSignedIn => 'Du er ikke logget inn.';

  @override
  String get profileSignInInConvoyHint => 'Innlogging er tilgjengelig i Kolonne-fanen.';

  @override
  String profileSignedInAs(Object name) {
    return 'Logget inn som: $name';
  }

  @override
  String get profileDefaultName => 'CruizX-sjåfør';

  @override
  String get profileSignedIn => 'Logget inn';

  @override
  String get profileStatsTitle => 'Statistikk';

  @override
  String get profileStatsConvoys => 'Kolonner kjørt';

  @override
  String get profileStatsTotalDistance => 'Total distanse';

  @override
  String get profileStatsSpeedViolations => 'Fartsoverskridelser';

  @override
  String get settingsTitle => 'Innstillinger';

  @override
  String get settingsLanguageLabel => 'Språk';

  @override
  String get settingsLanguageSystem => 'Systemstandard';

  @override
  String get settingsLanguageEnglish => 'Engelsk';

  @override
  String get settingsLanguageSwedish => 'Svensk';

  @override
  String get settingsLanguageFrench => 'Fransk';

  @override
  String get settingsLanguageNorwegian => 'Norsk';

  @override
  String get settingsLanguageDanish => 'Dansk';

  @override
  String get settingsLanguageFinnish => 'Finsk';

  @override
  String get settingsCountryLabel => 'Land (trafikkregler)';

  @override
  String get settingsCountrySweden => '🇸🇪 Sverige';

  @override
  String get settingsCountryNorway => '🇳🇴 Norge';

  @override
  String get settingsCountryDenmark => '🇩🇰 Danmark';

  @override
  String get settingsCountryFinland => '🇫🇮 Finland';

  @override
  String get settingsCountryFrance => '🇫🇷 Frankrike';

  @override
  String get settingsCountryHint => 'Fartsgrenser og veiregler tilpasses valgt land.';

  @override
  String settingsLanguageCurrentlyUsing(Object mode) {
    return 'Bruker nå: $mode';
  }

  @override
  String get settingsVehicleTypeLabel => 'Kjøretøytype';

  @override
  String get settingsVehicleAtractor => 'A-traktor';

  @override
  String get settingsVehicleMopedCar => 'Mopedbil';

  @override
  String get settingsVehicleTractor => 'Traktor';

  @override
  String get settingsSpeedUnitKmh => 'km/t';

  @override
  String get settingsSpeedUnitMph => 'mph';

  @override
  String settingsMaxSpeedWithUnit(Object value, Object unit) {
    return 'Maksfart: $value $unit';
  }

  @override
  String get settingsProCardTitle => 'CruizX Pro';

  @override
  String get settingsProStatusActive => 'Aktiv';

  @override
  String get settingsProStatusInactive => 'Ikke aktiv';

  @override
  String get settingsProDescriptionActive => 'Du har tilgang til alle Pro-funksjoner.';

  @override
  String get settingsProDescriptionInactive => 'Lås opp alle funksjoner med CruizX Pro.';

  @override
  String get settingsPrivacyPolicyLabel => 'Personvernregler';

  @override
  String get settingsTermsOfUseLabel => 'Bruksvilkår (EULA)';

  @override
  String get settingsSupportLabel => 'Support';

  @override
  String get settingsLinkOpenFailed => 'Kunne ikke åpne lenken akkurat nå.';

  @override
  String get settingsRestorePurchaseFailed => 'Kunne ikke gjenopprette kjøpet.';

  @override
  String get navigationTitle => 'Sving-for-sving-navigasjon';

  @override
  String get navigationSubtitle => 'Veibeskrivelse, neste sving og ankomsttid optimalisert for sakte kjøretøy.';

  @override
  String get mapStartingGps => 'Starter GPS...';

  @override
  String get mapTapToSelectDestination => 'Trykk på kartet for å velge destinasjon';

  @override
  String get mapAddressFieldHint => 'Søk adresse (f.eks. Karl Johans gate 1, Oslo)';

  @override
  String get mapSearchingAddress => 'Søker adresse...';

  @override
  String get mapAddressNotFound => 'Ingen adresse funnet. Prøv igjen.';

  @override
  String get mapAddressLookupFailed => 'Kunne ikke søke adresse akkurat nå';

  @override
  String get mapLocationServicesDisabled => 'Lokasjonstjenester er deaktivert';

  @override
  String get mapLocationPermissionMissing => 'Lokasjonstillatelse mangler';

  @override
  String get mapGpsActive => 'GPS aktiv';

  @override
  String get mapGpsUnavailable => 'GPS er ikke tilgjengelig i dette miljøet';

  @override
  String get mapWaitingForGps => 'Venter på GPS-posisjon før ruteberegning';

  @override
  String get mapCalculatingRoute => 'Beregner rute...';

  @override
  String mapRouteReady(Object distance, Object minutes) {
    return 'Rute klar: $distance km • $minutes min';
  }

  @override
  String get mapRouteFailed => 'Kunne ikke opprette rute akkurat nå';

  @override
  String get mapRemaining => 'igjen';

  @override
  String get mapRouteNoRouteFound => 'Ingen rute funnet mellom valgte punkter';

  @override
  String get mapRouteProviderUnavailable => 'Rutetjenesten er utilgjengelig akkurat nå';

  @override
  String get mapRouteMissingApiKey => 'Ruting er ikke konfigurert i backend (manglende API-nøkkel)';

  @override
  String get mapRouteInvalidGeometry => 'Rutedata fra serveren er ugyldig';

  @override
  String get mapRouteUnknownProvider => 'Ruteleverandøren er ikke riktig konfigurert';

  @override
  String get mapRouteTooFastForVehicle => 'Rute avvist: estimert gjennomsnittshastighet er for høy for denne kjøretøytypen.';

  @override
  String get mapRouteNotAllowedForVehicle => 'Ingen lovlig rute funnet for denne kjøretøytypen.';

  @override
  String get routeBlockedTitle => 'Rute ikke tilgjengelig';

  @override
  String routeBlockedBody(Object vehicleType) {
    return 'Ingen lovlig rute ble funnet til denne destinasjonen for din $vehicleType. Destinasjonen kan ligge ved eller kun nås via veier som ikke er tillatt for denne kjøretøytypen (f.eks. motorvei).';
  }

  @override
  String get routeBlockedOk => 'OK';

  @override
  String get routeBlockedTryOther => 'Prøv en annen destinasjon';

  @override
  String get mapModeLabel2d => '2D';

  @override
  String get mapModeLabel3d => '3D';

  @override
  String mapManeuverInDistance(Object distance) {
    return 'Om $distance';
  }

  @override
  String mapManeuverTowardRoad(Object road) {
    return 'Mot $road';
  }

  @override
  String get mapSimulateButton => 'Simuler';

  @override
  String get speedometerLiveSpeed => 'Nåværende fart';

  @override
  String speedometerMaxSpeedWithUnit(Object value, Object unit) {
    return 'Maksfart: $value $unit';
  }

  @override
  String get speedometerSlowDown => 'Senk farten.';

  @override
  String get reportAlertTitle => 'Rapporter varsel';

  @override
  String get reportAlertDescHint => 'Beskrivelse (valgfritt)';

  @override
  String get reportAlertSubmit => 'Send varsel';

  @override
  String reportAlertNearby(Object type, Object distance) {
    return '$type · $distance m foran';
  }

  @override
  String get alertTypePolice => 'Politi';

  @override
  String get alertTypeRoadwork => 'Veiarbeid';

  @override
  String get alertTypeAccident => 'Ulykke';

  @override
  String get alertTypeTrafficJam => 'Kø';

  @override
  String get alertTypeSpeedCamera => 'Fotoboks';

  @override
  String get alertTypeHazard => 'Fare';

  @override
  String get alertTypeNarrowRoad => 'Smal vei';

  @override
  String get alertTypeSteepHill => 'Bratt bakke';

  @override
  String get alertGpsUnavailable => 'GPS ikke tilgjengelig ennå';

  @override
  String get alertMustBeLoggedIn => 'Du må være logget inn for å rapportere';

  @override
  String get alertsScreenSubtitle => 'Varsler fra andre CruizX-sjåfører innen ~50 km. Trykk på tommel for å bekrefte et varsel.';

  @override
  String get alertReportButton => 'Rapporter';

  @override
  String get alertTimeJustNow => 'Akkurat nå';

  @override
  String alertTimeMinutes(Object n) {
    return '$n min siden';
  }

  @override
  String alertTimeHours(Object n) {
    return '$n t siden';
  }

  @override
  String get alertsEmptyTitle => 'Ingen aktive varsler i nærheten';

  @override
  String get alertsEmptySubtitle => 'Ser du noe på veien? Rapporter det!';

  @override
  String get alertReportQuestion => 'Hva ser du på veien?';

  @override
  String get alertReportDescHint2 => 'Valgfri beskrivelse… (f.eks. \"stor gren\")';

  @override
  String get alertReportedSuccess => 'Varsel rapportert! Takk 🙏';

  @override
  String get alertReportFailed => 'Kunne ikke rapportere varsel akkurat nå.';

  @override
  String get adBannerLoading => 'Laster annonse…';

  @override
  String get adBannerWaitingRetry => 'Annonse venter på nettverk… (trykk for å prøve igjen)';

  @override
  String get mapStartNavigation => 'Start navigasjon';

  @override
  String get mapEndNavigation => 'Avslutt navigasjon';

  @override
  String get convoyShowAll => 'Vis alle';

  @override
  String get convoyYouBadge => 'Deg';

  @override
  String convoyShareCopied(Object name, Object code) {
    return 'Kopiert! Del: \"$name\" kode: $code';
  }

  @override
  String convoyShareClipboard(Object name, Object code) {
    return 'CruizX kolonne: \"$name\" (kode: $code)';
  }

  @override
  String convoyPinMarkedBy(Object name) {
    return 'Markert av $name';
  }

  @override
  String get convoyNavigateToPin => 'Naviger hit';

  @override
  String get convoyEtaArrived => 'Fremme!';

  @override
  String convoyEtaMinutes(Object minutes, Object time) {
    return '$minutes min · $time';
  }

  @override
  String convoyEtaHours(Object hours, Object minutes, Object time) {
    return '${hours}t ${minutes}min · $time';
  }

  @override
  String get paywallTitle => 'Oppgrader til CruizX Pro';

  @override
  String get paywallSubtitle => 'Ingen begrensninger. Ingen annonser. Full tilgang.';

  @override
  String get paywallPrice => '42 kr / måned';

  @override
  String get paywallUpgradeButton => 'Oppgrader til Pro';

  @override
  String get paywallRestoreButton => 'Gjenopprett kjøp';

  @override
  String get paywallFreeLabel => 'Free';

  @override
  String get paywallProLabel => 'Pro';

  @override
  String get paywallFeatureRoutes => 'Ruter per dag';

  @override
  String get paywallFreeRouteLimit => '2 ruter';

  @override
  String get paywallProRouteLimit => 'Ubegrenset';

  @override
  String get paywallFeatureConvoy => 'Kolonne';

  @override
  String get paywallFreeConvoyLimit => '1 aktiv, 2 medlemmer';

  @override
  String get paywallProConvoyLimit => 'Ubegrenset';

  @override
  String get paywallFeatureAds => 'Annonser';

  @override
  String get paywallFreeAds => 'Vises';

  @override
  String get paywallProAds => 'Ingen';

  @override
  String get paywallRouteLimitTitle => 'Rutegrensen nådd';

  @override
  String get paywallRouteLimitBody => 'Gratisbrukere kan beregne 2 ruter per dag. Oppgrader til Pro for ubegrenset navigasjon.';

  @override
  String get paywallConvoyLimitTitle => 'Kolonnegrensen nådd';

  @override
  String get paywallConvoyLimitBody => 'Gratisbrukere kan bare være med i 1 kolonne om gangen.';

  @override
  String get paywallMemberLimitTitle => 'Kolonnen er full';

  @override
  String get paywallMemberLimitBody => 'Gratisbrukere kan bare bli med i kolonner med færre enn 2 medlemmer. Oppgrader til Pro for ubegrenset tilgang.';

  @override
  String get paywallPurchaseSuccess => 'Du er nå en Pro-bruker!';

  @override
  String get paywallRestoreSuccess => 'Kjøpet gjenopprettet!';

  @override
  String get paywallRestoreNotFound => 'Ingen tidligere kjøp funnet.';

  @override
  String get profileFreePlan => 'Gratisplan';

  @override
  String get profileProPlan => 'Pro-plan';

  @override
  String get profileUpgradeToPro => 'Oppgrader til Pro';

  @override
  String profileRoutesUsed(Object count, Object max) {
    return 'Ruter i dag: $count / $max';
  }

  @override
  String get profileChangePhoto => 'Bytt profilbilde';

  @override
  String get profileTakePhoto => 'Ta bilde';

  @override
  String get profileChooseFromGallery => 'Velg fra galleri';

  @override
  String get profilePhotoUploadFailed => 'Kunne ikke laste opp bilde';

  @override
  String get parentModeTitle => 'Foreldremodus';

  @override
  String get parentModeDescription => 'La en forelder følge kjøringen din i sanntid.';

  @override
  String get parentModeLoginRequired => 'Du må være logget inn for å bruke foreldremodus.';

  @override
  String get parentModeEnable => 'Aktiver foreldremodus';

  @override
  String get parentModeEnabledSubtitle => 'Foreldre kan følge kjøringen din';

  @override
  String get parentModeDisabledSubtitle => 'Ingen deling aktiv';

  @override
  String get parentModeInviteCode => 'Invitasjonskode';

  @override
  String get parentModeInviteCodeSubtitle => 'Del denne koden med forelderen din for å koble kontoen.';

  @override
  String get parentModeCopyCode => 'Kopier';

  @override
  String get parentModeShareCode => 'Del';

  @override
  String get parentModeCodeCopied => 'Kode kopiert!';

  @override
  String get parentModeShareSubject => 'CruizX Foreldrekode';

  @override
  String parentModeShareMessage(Object code) {
    return 'Hei! Bruk denne koden for å følge kjøringen min i CruizX: $code';
  }

  @override
  String get parentModeLinkedParents => 'Koblede foreldre';

  @override
  String get parentModeNoParentsLinked => 'Ingen foreldre koblet ennå. Del koden din!';

  @override
  String get parentModeUnlinkTitle => 'Fjerne forelder?';

  @override
  String parentModeUnlinkMessage(Object name) {
    return 'Vil du fjerne $name som forelder? De vil ikke lenger kunne følge kjøringen din.';
  }

  @override
  String get parentModeUnlink => 'Fjern';

  @override
  String get parentModeShareSettings => 'Hva som deles';

  @override
  String get parentModeShareLocation => 'Del posisjon';

  @override
  String get parentModeShareLocationSubtitle => 'Vis hvor du er på kartet';

  @override
  String get parentModeShareSpeed => 'Del hastighet';

  @override
  String get parentModeShareSpeedSubtitle => 'Vis nåværende hastighet';

  @override
  String get parentModeAlertSettings => 'Varsler til foreldre';

  @override
  String get parentModeSpeedAlert => 'Fartsvarsel';

  @override
  String parentModeSpeedAlertSubtitle(Object limit) {
    return 'Varsle når farten overstiger $limit km/t';
  }

  @override
  String get parentModeSpeedLimit => 'Grense';

  @override
  String get parentModeNightAlert => 'Nattkjøringsvarsel';

  @override
  String parentModeNightAlertSubtitle(Object start, Object end) {
    return 'Varsle ved kjøring mellom kl. $start–$end';
  }

  @override
  String get cancel => 'Avbryt';

  @override
  String get login => 'Logg inn';

  @override
  String get parentDashboardTitle => 'Foreldredashboard';

  @override
  String get parentDashboardMapTab => 'Kart';

  @override
  String get parentDashboardAlertsTab => 'Varsler';

  @override
  String get parentDashboardAddChild => 'Legg til barn';

  @override
  String get parentDashboardOnline => 'Tilkoblet';

  @override
  String get parentDashboardOffline => 'Frakoblet';

  @override
  String get parentDashboardNoAlerts => 'Ingen varsler de siste 24 timene';

  @override
  String get parentDashboardNoChildren => 'Ingen barn koblet ennå';

  @override
  String get parentDashboardNoChildrenHint => 'Legg til et barn ved å skrive inn invitasjonskoden fra CruizX Foreldremodus.';

  @override
  String get parentDashboardEnterCode => 'Skriv inn invitasjonskode';

  @override
  String get parentDashboardEnterCodeHint => 'Be barnet ditt dele sin 6-tegns invitasjonskode fra Foreldremodus-innstillingene.';

  @override
  String get parentDashboardLink => 'Koble';

  @override
  String get parentDashboardLinkSuccess => 'Koblingen var vellykket!';

  @override
  String get parentDashboardLinkFailed => 'Kunne ikke finne barn med den koden. Sjekk koden og prøv igjen.';

  @override
  String get parentDashboardLinkSelf => 'Du kan ikke koble til din egen konto. Be barnet ditt dele sin kode fra sin konto.';

  @override
  String get parentDashboardSpeedingAlert => 'Fartsvarsel';

  @override
  String parentDashboardSpeedingDetail(Object name, Object speed, Object limit) {
    return '$name kjørte i $speed km/t (grense: $limit km/t)';
  }

  @override
  String get parentDashboardNightAlert => 'Nattkjøring';

  @override
  String parentDashboardNightDetail(Object name) {
    return '$name kjører om natten';
  }

  @override
  String get parentDashboardViewChild => 'Vis som forelder';

  @override
  String get settingsVoiceNavigation => 'Talenavigasjon';

  @override
  String get settingsVoiceNavigationSubtitle => 'Les opp svingeinstruksjoner';

  @override
  String get voiceTurnLeft => 'Sving til venstre';

  @override
  String get voiceTurnRight => 'Sving til høyre';

  @override
  String get voiceTurnSharpLeft => 'Sving skarpt til venstre';

  @override
  String get voiceTurnSharpRight => 'Sving skarpt til høyre';

  @override
  String get voiceTurnSlightLeft => 'Sving svakt til venstre';

  @override
  String get voiceTurnSlightRight => 'Sving svakt til høyre';

  @override
  String get voiceContinue => 'Fortsett rett frem';

  @override
  String get voiceRoundabout => 'Kjør inn i rundkjøringen';

  @override
  String get voiceDestination => 'Du har nådd destinasjonen';

  @override
  String voiceInMeters(Object meters) {
    return 'Om $meters meter';
  }

  @override
  String voiceInKm(Object km) {
    return 'Om $km kilometer';
  }

  @override
  String get mfaSetupTitle => 'Aktiver tofaktorautentisering';

  @override
  String get mfaSetupSubtitle => 'Skann QR-koden med en autentiseringsapp som Google Authenticator eller Authy';

  @override
  String get mfaScanQr => 'Skann koden over og skriv inn den 6-sifrede koden under';

  @override
  String get mfaVerifyButton => 'Bekreft';

  @override
  String get mfaVerifyTitle => 'Tofaktorautentisering';

  @override
  String get mfaVerifySubtitle => 'Skriv inn den 6-sifrede koden fra autentiseringsappen din';

  @override
  String get mfaInvalidCode => 'Ugyldig kode, prøv igjen';

  @override
  String get mfaCancel => 'Avbryt og logg ut';

  @override
  String get mfaProfileTitle => 'Tofaktorautentisering';

  @override
  String get mfaStatusOn => 'Aktivert — kontoen din er beskyttet';

  @override
  String get mfaStatusOff => 'Deaktivert';

  @override
  String get mfaTurnOn => 'Aktiver';

  @override
  String get mfaTurnOff => 'Slå av';

  @override
  String get mfaDisableTitle => 'Slå av 2FA?';

  @override
  String get mfaDisableBody => 'Kontoen din blir mindre sikker uten tofaktorautentisering.';

  @override
  String get mfaDisableConfirm => 'Slå av';

  @override
  String get mfaShowManualKey => 'Kan du ikke skanne? Vis nøkkel manuelt';

  @override
  String get mfaHideManualKey => 'Skjul manuell nøkkel';

  @override
  String get mfaKeyCopied => 'Nøkkel kopiert';

  @override
  String get mfaRecommendTitle => 'Beskytt kontoen din';

  @override
  String get mfaRecommendBody => 'Vi anbefaler å aktivere tofaktorautentisering for å beskytte kontoen din. Du kan bruke en autentiseringsapp som Google Authenticator eller Authy.';

  @override
  String get mfaRecommendSetup => 'Aktiver nå';

  @override
  String get mfaRecommendLater => 'Senere';

  @override
  String get favHome => 'Hjem';

  @override
  String get favSchool => 'Skole';

  @override
  String get favWork => 'Jobb';

  @override
  String get favAddTitle => 'Lagre sted';

  @override
  String get favLabelHint => 'Navn (f.eks. Kompis)';

  @override
  String get favSaved => 'Sted lagret';

  @override
  String get favDeleted => 'Sted fjernet';

  @override
  String favDeleteConfirm(Object name) {
    return 'Fjerne $name?';
  }

  @override
  String favSetAs(Object type) {
    return 'Lagre som $type';
  }

  @override
  String get favCustom => 'Annen favoritt';

  @override
  String get ttsVoiceHint => 'Tips: Last ned bedre stemmer i Innstillinger → Tilgjengelighet → Opplest innhold → Stemmer';

  @override
  String get ttsVoiceHintDismiss => 'OK';
}
