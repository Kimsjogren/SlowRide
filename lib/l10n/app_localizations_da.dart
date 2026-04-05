// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class AppLocalizationsDa extends AppLocalizations {
  AppLocalizationsDa([String locale = 'da']) : super(locale);

  @override
  String get appTitle => 'CruizX';

  @override
  String get navMap => 'Kort';

  @override
  String get navAlerts => 'Advarsler';

  @override
  String get navConvoy => 'Konvoj';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSettings => 'Indstillinger';

  @override
  String get splashPreparingStartup => 'Forbereder opstart...';

  @override
  String get splashLoadingCoreModules => 'Indlæser kernemoduler...';

  @override
  String get splashInitializingAccountSession => 'Initialiserer kontosession...';

  @override
  String get splashLoadingPreferences => 'Indlæser indstillinger...';

  @override
  String get splashFinalizingStartup => 'Afslutter opstart...';

  @override
  String get splashReady => 'Klar';

  @override
  String get splashVersionLine => 'v1.0.0 | CruizX by KimTechTool';

  @override
  String get alertsTitle => 'Fællesskabsadvarsler';

  @override
  String get alertsSubtitle => 'Rapportér og se vejfarer, kontroller og vejforhold.';

  @override
  String get convoyRequiresSignInTitle => 'Konvoj kræver login';

  @override
  String get convoyRequiresSignInSubtitle => 'Log ind eller opret en konto her for at oprette konvojgrupper og se live-positioner.';

  @override
  String get signIn => 'Log ind';

  @override
  String get signUp => 'Opret konto';

  @override
  String get signOut => 'Log ud';

  @override
  String get signInEmailDialogTitle => 'Log ind med e-mail OTP';

  @override
  String get signUpEmailDialogTitle => 'Opret konto med e-mail OTP';

  @override
  String get signInEmailFieldLabel => 'E-mail';

  @override
  String get signInEmailHint => 'navn@eksempel.dk';

  @override
  String get signInSendOtp => 'Send kode';

  @override
  String get signUpSendOtp => 'Send kontokode';

  @override
  String get signInOtpFieldLabel => 'OTP-kode';

  @override
  String get signInOtpHint => '6-cifret kode';

  @override
  String get signInVerifyOtp => 'Bekræft kode';

  @override
  String get signInOtpSent => 'OTP-kode sendt til din e-mail.';

  @override
  String get signUpOtpSent => 'Kontooprettelseskode sendt til din e-mail.';

  @override
  String get signInOtpInvalid => 'Kunne ikke bekræfte OTP. Tjek din kode og prøv igen.';

  @override
  String get signUpNoAccountAction => 'Ingen konto? Opret en';

  @override
  String get signUpHaveAccountAction => 'Har du allerede en konto? Log ind';

  @override
  String get authGenericError => 'Noget gik galt. Prøv igen.';

  @override
  String get authWelcomeBack => 'Velkommen tilbage til CruizX';

  @override
  String get authRegisterSubtitle => 'Bliv en del af CruizX-fællesskabet';

  @override
  String get authEmailLabel => 'E-mailadresse';

  @override
  String get authEmailRequired => 'Indtast din e-mailadresse';

  @override
  String get authEmailInvalid => 'Ugyldig e-mail';

  @override
  String get authPasswordLabel => 'Adgangskode';

  @override
  String get authPasswordRequired => 'Indtast din adgangskode';

  @override
  String get authPasswordMinLength => 'Mindst 6 tegn';

  @override
  String get authConfirmPasswordLabel => 'Bekræft adgangskode';

  @override
  String get authConfirmPasswordRequired => 'Bekræft din adgangskode';

  @override
  String get authPasswordsDoNotMatch => 'Adgangskoderne stemmer ikke overens.';

  @override
  String get authDisplayNameLabel => 'Visningsnavn';

  @override
  String get authDisplayNameRequired => 'Indtast dit navn';

  @override
  String get authNoAccountPrompt => 'Ingen konto? ';

  @override
  String get authAlreadyHaveAccountPrompt => 'Har du allerede en konto? ';

  @override
  String get authCancel => 'Annuller';

  @override
  String get authForgotPasswordLink => 'Glemt adgangskode?';

  @override
  String get authForgotPasswordTitle => 'Nulstil adgangskode';

  @override
  String get authForgotPasswordDescription => 'Indtast din e-mailadresse, så sender vi dig et link til at nulstille din adgangskode.';

  @override
  String get authForgotPasswordButton => 'Send nulstillingslink';

  @override
  String get authForgotPasswordSuccess => 'Hvis kontoen findes, har vi sendt et nulstillingslink til din e-mail.';

  @override
  String get authResetPasswordTitle => 'Ny adgangskode';

  @override
  String get authResetPasswordDescription => 'Indtast din nye adgangskode nedenfor.';

  @override
  String get authNewPasswordLabel => 'Ny adgangskode';

  @override
  String get authResetPasswordButton => 'Gem adgangskode';

  @override
  String get authResetPasswordSuccess => 'Din adgangskode er blevet ændret.';

  @override
  String get authErrorAllFieldsRequired => 'Alle felter er påkrævet.';

  @override
  String get authErrorPasswordTooShort => 'Adgangskoden skal være mindst 6 tegn.';

  @override
  String get authErrorConfirmEmail => 'Tjek din e-mail for at bekræfte din konto, og log derefter ind.';

  @override
  String get authErrorEmailAndPasswordRequired => 'Indtast e-mail og adgangskode.';

  @override
  String get authErrorInvalidCredentials => 'Forkert e-mail eller adgangskode.';

  @override
  String get authErrorEmailAlreadyInUse => 'Der findes allerede en konto med den e-mailadresse.';

  @override
  String get convoyRealtimeBackendMissing => 'Realtidskonvoj er ikke konfigureret endnu. Tilføj backend-konfiguration for at dele live-position mellem brugere.';

  @override
  String get convoyModeTitle => 'Konvojtilstand';

  @override
  String get convoyModeSubtitle => 'Opret gruppekørsel med delt destination og live-positioner.';

  @override
  String get convoyCreateButton => 'Opret konvoj';

  @override
  String get convoyOpenButton => 'Åbn';

  @override
  String get convoyJoinButton => 'Deltag';

  @override
  String get convoyLeaveButton => 'Forlad';

  @override
  String get convoyJoinFirstHint => 'Deltag i konvojen først, og tryk derefter for at åbne chat og kort.';

  @override
  String get convoyJoinByCodeTitle => 'Deltag i konvoj';

  @override
  String get convoyJoinByCodeHint => 'Indtast den konvojkode du har modtaget';

  @override
  String get convoyJoinWithCodeButton => 'Deltag';

  @override
  String get convoyJoinByCodeNotFound => 'Ingen konvoj fundet med den kode.';

  @override
  String convoyJoinByCodeSuccess(String name) {
    return 'Du deltog i $name!';
  }

  @override
  String get convoyInviteButton => 'Invitér';

  @override
  String get convoyTabMap => 'Kort';

  @override
  String get convoyTabChat => 'Chat';

  @override
  String get convoyMapHint => 'Tryk på kortet for at placere en delt markør.';

  @override
  String get convoyRecenterTooltip => 'Centrér og følg min position';

  @override
  String get convoyPinDialogTitle => 'Tilføj kortmarkør';

  @override
  String get convoyPinLabel => 'Markørnavn';

  @override
  String get convoyPinHint => 'f.eks. Mød os her';

  @override
  String get convoyPinAdd => 'Tilføj markør';

  @override
  String get convoyHazardPolice => 'Politi';

  @override
  String get convoyHazardRoadwork => 'Vejarbejde';

  @override
  String get convoyHazardAccident => 'Ulykke';

  @override
  String get convoyHazardTrafficJam => 'Kø';

  @override
  String get convoyHazardSpeedCamera => 'Fotofælde';

  @override
  String get convoyHazardCustom => 'Brugerdefineret markør';

  @override
  String get convoyChatEmpty => 'Ingen beskeder endnu.';

  @override
  String get convoyChatPlaceholder => 'Skriv en besked...';

  @override
  String get convoyChatSend => 'Send';

  @override
  String get convoyNameDialogTitle => 'Opret konvoj';

  @override
  String get convoyNameFieldLabel => 'Konvojnavn';

  @override
  String get convoyNameHint => 'f.eks. Fredagskørsel';

  @override
  String get convoyCreateConfirm => 'Opret';

  @override
  String get convoyCreateCancel => 'Annuller';

  @override
  String get convoyListEmpty => 'Ingen konvojer endnu. Opret den første.';

  @override
  String get convoyListEmptyMine => 'Du har ikke deltaget i nogen konvojer endnu.';

  @override
  String get convoyFilterAll => 'Alle';

  @override
  String get convoyFilterMine => 'Mine';

  @override
  String convoyMembers(Object count) {
    return '$count medlemmer';
  }

  @override
  String get convoyMemberMe => 'Mig';

  @override
  String convoyMemberStaleTime(Object mins) {
    return '${mins}m siden';
  }

  @override
  String convoyCreatedBy(Object leader) {
    return 'Oprettet af $leader';
  }

  @override
  String get profileTitle => 'Profil & Statistik';

  @override
  String get profileNotSignedIn => 'Du er ikke logget ind.';

  @override
  String get profileSignInInConvoyHint => 'Login er tilgængelig under fanen Konvoj.';

  @override
  String profileSignedInAs(Object name) {
    return 'Logget ind som: $name';
  }

  @override
  String get profileDefaultName => 'CruizX-chauffør';

  @override
  String get profileSignedIn => 'Logget ind';

  @override
  String get profileStatsTitle => 'Statistik';

  @override
  String get profileStatsConvoys => 'Konvojer kørt';

  @override
  String get profileStatsTotalDistance => 'Samlet distance';

  @override
  String get profileStatsSpeedViolations => 'Hastighedsovertrædelser';

  @override
  String get settingsTitle => 'Indstillinger';

  @override
  String get settingsLanguageLabel => 'Sprog';

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
  String get settingsCountryLabel => 'Land (færdelsregler)';

  @override
  String get settingsCountrySweden => '🇸🇪 Sverige';

  @override
  String get settingsCountryNorway => '🇳🇴 Norge';

  @override
  String get settingsCountryDenmark => '🇩🇰 Danmark';

  @override
  String get settingsCountryFinland => '🇫🇮 Finland';

  @override
  String get settingsCountryFrance => '🇫🇷 Frankrig';

  @override
  String get settingsCountryHint => 'Hastighedsgrænser og vejregler tilpasses det valgte land.';

  @override
  String settingsLanguageCurrentlyUsing(Object mode) {
    return 'Bruger nu: $mode';
  }

  @override
  String get settingsVehicleTypeLabel => 'Køretøjstype';

  @override
  String get settingsVehicleAtractor => 'A-traktor';

  @override
  String get settingsVehicleMopedCar => 'Knallertbil';

  @override
  String get settingsVehicleTractor => 'Traktor';

  @override
  String get settingsSpeedUnitKmh => 'km/t';

  @override
  String get settingsSpeedUnitMph => 'mph';

  @override
  String settingsMaxSpeedWithUnit(Object value, Object unit) {
    return 'Maks hastighed: $value $unit';
  }

  @override
  String get settingsProCardTitle => 'CruizX Pro';

  @override
  String get settingsProStatusActive => 'Aktiv';

  @override
  String get settingsProStatusInactive => 'Ikke aktiv';

  @override
  String get settingsProDescriptionActive => 'Du har adgang til alle Pro-funktioner.';

  @override
  String get settingsProDescriptionInactive => 'Lås alle funktioner op med CruizX Pro.';

  @override
  String get settingsPrivacyPolicyLabel => 'Privatlivspolitik';

  @override
  String get settingsTermsOfUseLabel => 'Brugsvilkår (EULA)';

  @override
  String get settingsLinkOpenFailed => 'Kunne ikke åbne linket lige nu.';

  @override
  String get settingsRestorePurchaseFailed => 'Kunne ikke gendanne købet.';

  @override
  String get navigationTitle => 'Sving-for-sving-navigation';

  @override
  String get navigationSubtitle => 'Vejvejledning, næste sving og ankomsttid optimeret til langsomme køretøjer.';

  @override
  String get mapStartingGps => 'Starter GPS...';

  @override
  String get mapTapToSelectDestination => 'Tryk på kortet for at vælge destination';

  @override
  String get mapAddressFieldHint => 'Søg adresse (f.eks. Strøget 1, København)';

  @override
  String get mapSearchingAddress => 'Søger adresse...';

  @override
  String get mapAddressNotFound => 'Ingen adresse fundet. Prøv igen.';

  @override
  String get mapAddressLookupFailed => 'Kunne ikke søge adresse lige nu';

  @override
  String get mapLocationServicesDisabled => 'Placeringstjenester er deaktiveret';

  @override
  String get mapLocationPermissionMissing => 'Placeringstilladelse mangler';

  @override
  String get mapGpsActive => 'GPS aktiv';

  @override
  String get mapGpsUnavailable => 'GPS er ikke tilgængelig i dette miljø';

  @override
  String get mapWaitingForGps => 'Venter på GPS-position inden ruteberegning';

  @override
  String get mapCalculatingRoute => 'Beregner rute...';

  @override
  String mapRouteReady(Object distance, Object minutes) {
    return 'Rute klar: $distance km • $minutes min';
  }

  @override
  String get mapRouteFailed => 'Kunne ikke oprette rute lige nu';

  @override
  String get mapRemaining => 'tilbage';

  @override
  String get mapRouteNoRouteFound => 'Ingen rute fundet mellem de valgte punkter';

  @override
  String get mapRouteProviderUnavailable => 'Rutetjenesten er utilgængelig lige nu';

  @override
  String get mapRouteMissingApiKey => 'Ruting er ikke konfigureret i backend (manglende API-nøgle)';

  @override
  String get mapRouteInvalidGeometry => 'Rutedata fra serveren er ugyldig';

  @override
  String get mapRouteUnknownProvider => 'Ruteleverandøren er ikke korrekt konfigureret';

  @override
  String get mapRouteTooFastForVehicle => 'Rute afvist: estimeret gennemsnitshastighed er for høj til denne køretøjstype.';

  @override
  String get mapRouteNotAllowedForVehicle => 'Ingen lovlig rute fundet til denne køretøjstype.';

  @override
  String get routeBlockedTitle => 'Rute ikke tilgængelig';

  @override
  String routeBlockedBody(Object vehicleType) {
    return 'Ingen lovlig rute blev fundet til denne destination for din $vehicleType. Destinationen befinder sig måske ved eller kan kun nås via veje, der ikke er tilladt for denne køretøjstype (f.eks. motorvej).';
  }

  @override
  String get routeBlockedOk => 'OK';

  @override
  String get routeBlockedTryOther => 'Prøv en anden destination';

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
    return 'Mod $road';
  }

  @override
  String get mapSimulateButton => 'Simulér';

  @override
  String get speedometerLiveSpeed => 'Aktuel hastighed';

  @override
  String speedometerMaxSpeedWithUnit(Object value, Object unit) {
    return 'Maks hastighed: $value $unit';
  }

  @override
  String get speedometerSlowDown => 'Sænk farten.';

  @override
  String get reportAlertTitle => 'Rapportér advarsel';

  @override
  String get reportAlertDescHint => 'Beskrivelse (valgfrit)';

  @override
  String get reportAlertSubmit => 'Send advarsel';

  @override
  String reportAlertNearby(Object type, Object distance) {
    return '$type · $distance m forude';
  }

  @override
  String get alertTypePolice => 'Politi';

  @override
  String get alertTypeRoadwork => 'Vejarbejde';

  @override
  String get alertTypeAccident => 'Ulykke';

  @override
  String get alertTypeTrafficJam => 'Kø';

  @override
  String get alertTypeSpeedCamera => 'Fotofælde';

  @override
  String get alertTypeHazard => 'Fare';

  @override
  String get alertTypeNarrowRoad => 'Smal vej';

  @override
  String get alertTypeSteepHill => 'Stejl bakke';

  @override
  String get alertGpsUnavailable => 'GPS ikke tilgængelig endnu';

  @override
  String get alertMustBeLoggedIn => 'Du skal være logget ind for at rapportere';

  @override
  String get alertsScreenSubtitle => 'Advarsler fra andre CruizX-chauffører inden for ~50 km. Tryk på tommel for at bekræfte en advarsel.';

  @override
  String get alertReportButton => 'Rapportér';

  @override
  String get alertTimeJustNow => 'Lige nu';

  @override
  String alertTimeMinutes(Object n) {
    return '$n min siden';
  }

  @override
  String alertTimeHours(Object n) {
    return '$n t siden';
  }

  @override
  String get alertsEmptyTitle => 'Ingen aktive advarsler i nærheden';

  @override
  String get alertsEmptySubtitle => 'Ser du noget på vejen? Rapportér det!';

  @override
  String get alertReportQuestion => 'Hvad ser du på vejen?';

  @override
  String get alertReportDescHint2 => 'Valgfri beskrivelse… (f.eks. \"stor gren\")';

  @override
  String get alertReportedSuccess => 'Advarsel rapporteret! Tak 🙏';

  @override
  String get alertReportFailed => 'Kunne ikke rapportere advarsel lige nu.';

  @override
  String get adBannerLoading => 'Indlæser annonce…';

  @override
  String get adBannerWaitingRetry => 'Annonce venter på netværk… (tryk for at prøve igen)';

  @override
  String get mapStartNavigation => 'Start navigation';

  @override
  String get mapEndNavigation => 'Afslut navigation';

  @override
  String get convoyShowAll => 'Vis alle';

  @override
  String get convoyYouBadge => 'Dig';

  @override
  String convoyShareCopied(Object name, Object code) {
    return 'Kopieret! Del: \"$name\" kode: $code';
  }

  @override
  String convoyShareClipboard(Object name, Object code) {
    return 'CruizX konvoj: \"$name\" (kode: $code)';
  }

  @override
  String convoyPinMarkedBy(Object name) {
    return 'Markeret af $name';
  }

  @override
  String get convoyNavigateToPin => 'Navigér hertil';

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
  String get paywallTitle => 'Opgrader til CruizX Pro';

  @override
  String get paywallSubtitle => 'Ingen begrænsninger. Ingen reklamer. Fuld adgang.';

  @override
  String get paywallPrice => '29 kr / måned';

  @override
  String get paywallUpgradeButton => 'Opgrader til Pro';

  @override
  String get paywallRestoreButton => 'Gendan køb';

  @override
  String get paywallFreeLabel => 'Free';

  @override
  String get paywallProLabel => 'Pro';

  @override
  String get paywallFeatureRoutes => 'Ruter per dag';

  @override
  String get paywallFreeRouteLimit => '2 ruter';

  @override
  String get paywallProRouteLimit => 'Ubegrænset';

  @override
  String get paywallFeatureConvoy => 'Konvoj';

  @override
  String get paywallFreeConvoyLimit => '1 aktiv, 2 medlemmer';

  @override
  String get paywallProConvoyLimit => 'Ubegrænset';

  @override
  String get paywallFeatureAds => 'Reklamer';

  @override
  String get paywallFreeAds => 'Vises';

  @override
  String get paywallProAds => 'Ingen';

  @override
  String get paywallRouteLimitTitle => 'Daglig rutegrænse nået';

  @override
  String get paywallRouteLimitBody => 'Gratisbrugere kan beregne 2 ruter per dag. Opgrader til Pro for ubegrænset navigation.';

  @override
  String get paywallConvoyLimitTitle => 'Konvojgrænse nået';

  @override
  String get paywallConvoyLimitBody => 'Gratisbrugere kan kun være med i 1 konvoj ad gangen.';

  @override
  String get paywallMemberLimitTitle => 'Konvojen er fuld';

  @override
  String get paywallMemberLimitBody => 'Gratisbrugere kan kun deltage i konvojer med færre end 2 medlemmer. Opgrader til Pro for ubegrænset adgang.';

  @override
  String get paywallPurchaseSuccess => 'Du er nu en Pro-bruger!';

  @override
  String get paywallRestoreSuccess => 'Købet gendannet!';

  @override
  String get paywallRestoreNotFound => 'Intet tidligere køb fundet.';

  @override
  String get profileFreePlan => 'Gratis plan';

  @override
  String get profileProPlan => 'Pro-plan';

  @override
  String get profileUpgradeToPro => 'Opgrader til Pro';

  @override
  String profileRoutesUsed(Object count, Object max) {
    return 'Ruter i dag: $count / $max';
  }

  @override
  String get profileChangePhoto => 'Skift profilbillede';

  @override
  String get profileTakePhoto => 'Tag foto';

  @override
  String get profileChooseFromGallery => 'Vælg fra galleri';

  @override
  String get profilePhotoUploadFailed => 'Kunne ikke uploade foto';

  @override
  String get parentModeTitle => 'Forældretilstand';

  @override
  String get parentModeDescription => 'Lad en forælder følge din kørsel i realtid.';

  @override
  String get parentModeLoginRequired => 'Du skal være logget ind for at bruge forældretilstand.';

  @override
  String get parentModeEnable => 'Aktivér forældretilstand';

  @override
  String get parentModeEnabledSubtitle => 'Forældre kan følge din kørsel';

  @override
  String get parentModeDisabledSubtitle => 'Ingen deling aktiv';

  @override
  String get parentModeInviteCode => 'Invitationskode';

  @override
  String get parentModeInviteCodeSubtitle => 'Del denne kode med din forælder for at sammenkæde deres konto.';

  @override
  String get parentModeCopyCode => 'Kopiér';

  @override
  String get parentModeShareCode => 'Del';

  @override
  String get parentModeCodeCopied => 'Kode kopieret!';

  @override
  String get parentModeShareSubject => 'CruizX Forældrekode';

  @override
  String parentModeShareMessage(Object code) {
    return 'Hej! Brug denne kode til at følge min kørsel i CruizX: $code';
  }

  @override
  String get parentModeLinkedParents => 'Sammenkædede forældre';

  @override
  String get parentModeNoParentsLinked => 'Ingen forældre sammenkædet endnu. Del din kode!';

  @override
  String get parentModeUnlinkTitle => 'Fjern forælder?';

  @override
  String parentModeUnlinkMessage(Object name) {
    return 'Vil du fjerne $name som forælder? De vil ikke længere kunne følge din kørsel.';
  }

  @override
  String get parentModeUnlink => 'Fjern';

  @override
  String get parentModeShareSettings => 'Hvad der deles';

  @override
  String get parentModeShareLocation => 'Del position';

  @override
  String get parentModeShareLocationSubtitle => 'Vis hvor du er på kortet';

  @override
  String get parentModeShareSpeed => 'Del hastighed';

  @override
  String get parentModeShareSpeedSubtitle => 'Vis din aktuelle hastighed';

  @override
  String get parentModeAlertSettings => 'Notifikationer til forældre';

  @override
  String get parentModeSpeedAlert => 'Hastighedsadvarsel';

  @override
  String parentModeSpeedAlertSubtitle(Object limit) {
    return 'Advisér når hastigheden overstiger $limit km/t';
  }

  @override
  String get parentModeSpeedLimit => 'Grænse';

  @override
  String get parentModeNightAlert => 'Natkørselsadvarsel';

  @override
  String parentModeNightAlertSubtitle(Object start, Object end) {
    return 'Advisér ved kørsel mellem kl. $start–$end';
  }

  @override
  String get cancel => 'Annuller';

  @override
  String get login => 'Log ind';

  @override
  String get parentDashboardTitle => 'Forældredashboard';

  @override
  String get parentDashboardMapTab => 'Kort';

  @override
  String get parentDashboardAlertsTab => 'Advarsler';

  @override
  String get parentDashboardAddChild => 'Tilføj barn';

  @override
  String get parentDashboardOnline => 'Online';

  @override
  String get parentDashboardOffline => 'Offline';

  @override
  String get parentDashboardNoAlerts => 'Ingen advarsler de sidste 24 timer';

  @override
  String get parentDashboardNoChildren => 'Ingen børn sammenkædet endnu';

  @override
  String get parentDashboardNoChildrenHint => 'Tilføj et barn ved at indtaste deres invitationskode fra CruizX Forældretilstand.';

  @override
  String get parentDashboardEnterCode => 'Indtast invitationskode';

  @override
  String get parentDashboardEnterCodeHint => 'Bed dit barn dele sin 6-tegns invitationskode fra Forældretilstand-indstillingerne.';

  @override
  String get parentDashboardLink => 'Sammenkæd';

  @override
  String get parentDashboardLinkSuccess => 'Sammenkædning lykkedes!';

  @override
  String get parentDashboardLinkFailed => 'Kunne ikke finde barn med den kode. Tjek koden og prøv igen.';

  @override
  String get parentDashboardLinkSelf => 'Du kan ikke sammenkæde med din egen konto. Bed dit barn dele sin kode fra sin konto.';

  @override
  String get parentDashboardSpeedingAlert => 'Hastighedsadvarsel';

  @override
  String parentDashboardSpeedingDetail(Object name, Object speed, Object limit) {
    return '$name kørte $speed km/t (grænse: $limit km/t)';
  }

  @override
  String get parentDashboardNightAlert => 'Natkørsel';

  @override
  String parentDashboardNightDetail(Object name) {
    return '$name kører om natten';
  }

  @override
  String get parentDashboardViewChild => 'Vis som forælder';

  @override
  String get settingsVoiceNavigation => 'Talenavigation';

  @override
  String get settingsVoiceNavigationSubtitle => 'Læs svingeinstruktioner højt';

  @override
  String get voiceTurnLeft => 'Drej til venstre';

  @override
  String get voiceTurnRight => 'Drej til højre';

  @override
  String get voiceTurnSharpLeft => 'Drej skarpt til venstre';

  @override
  String get voiceTurnSharpRight => 'Drej skarpt til højre';

  @override
  String get voiceTurnSlightLeft => 'Drej let til venstre';

  @override
  String get voiceTurnSlightRight => 'Drej let til højre';

  @override
  String get voiceContinue => 'Fortsæt ligeud';

  @override
  String get voiceRoundabout => 'Kør ind i rundkørslen';

  @override
  String get voiceDestination => 'Du er nået frem til din destination';

  @override
  String voiceInMeters(Object meters) {
    return 'Om $meters meter';
  }

  @override
  String voiceInKm(Object km) {
    return 'Om $km kilometer';
  }

  @override
  String get mfaSetupTitle => 'Aktivér tofaktorbekræftelse';

  @override
  String get mfaSetupSubtitle => 'Scan QR-koden med en godkendelsesapp som Google Authenticator eller Authy';

  @override
  String get mfaScanQr => 'Scan koden ovenfor og indtast den 6-cifrede kode nedenfor';

  @override
  String get mfaVerifyButton => 'Bekræft';

  @override
  String get mfaVerifyTitle => 'Tofaktorbekræftelse';

  @override
  String get mfaVerifySubtitle => 'Indtast den 6-cifrede kode fra din godkendelsesapp';

  @override
  String get mfaInvalidCode => 'Ugyldig kode, prøv igen';

  @override
  String get mfaCancel => 'Annuller og log ud';

  @override
  String get mfaProfileTitle => 'Tofaktorbekræftelse';

  @override
  String get mfaStatusOn => 'Aktiveret — din konto er beskyttet';

  @override
  String get mfaStatusOff => 'Deaktiveret';

  @override
  String get mfaTurnOn => 'Aktivér';

  @override
  String get mfaTurnOff => 'Deaktivér';

  @override
  String get mfaDisableTitle => 'Deaktivér 2FA?';

  @override
  String get mfaDisableBody => 'Din konto bliver mindre sikker uden tofaktorbekræftelse.';

  @override
  String get mfaDisableConfirm => 'Deaktivér';

  @override
  String get mfaShowManualKey => 'Kan du ikke scanne? Vis nøgle manuelt';

  @override
  String get mfaHideManualKey => 'Skjul manuel nøgle';

  @override
  String get mfaKeyCopied => 'Nøgle kopieret';

  @override
  String get mfaRecommendTitle => 'Beskyt din konto';

  @override
  String get mfaRecommendBody => 'Vi anbefaler at aktivere tofaktorbekræftelse for at beskytte din konto. Du kan bruge en godkendelsesapp som Google Authenticator eller Authy.';

  @override
  String get mfaRecommendSetup => 'Aktivér nu';

  @override
  String get mfaRecommendLater => 'Senere';

  @override
  String get favHome => 'Hjem';

  @override
  String get favSchool => 'Skole';

  @override
  String get favWork => 'Arbejde';

  @override
  String get favAddTitle => 'Gem sted';

  @override
  String get favLabelHint => 'Navn (f.eks. Ven)';

  @override
  String get favSaved => 'Sted gemt';

  @override
  String get favDeleted => 'Sted fjernet';

  @override
  String favDeleteConfirm(Object name) {
    return 'Fjern $name?';
  }

  @override
  String favSetAs(Object type) {
    return 'Gem som $type';
  }

  @override
  String get favCustom => 'Anden favorit';

  @override
  String get ttsVoiceHint => 'Tip: Download bedre stemmer i Indstillinger → Tilgængelighed → Oplæst indhold → Stemmer';

  @override
  String get ttsVoiceHintDismiss => 'OK';
}
