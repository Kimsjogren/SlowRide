// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'CruizX';

  @override
  String get navMap => 'Karta';

  @override
  String get navAlerts => 'Varningar';

  @override
  String get navConvoy => 'Konvoj';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSettings => 'Inställningar';

  @override
  String get splashPreparingStartup => 'Förbereder uppstart...';

  @override
  String get splashLoadingCoreModules => 'Laddar kärnmoduler...';

  @override
  String get splashInitializingAccountSession => 'Initierar kontosession...';

  @override
  String get splashLoadingPreferences => 'Laddar inställningar...';

  @override
  String get splashFinalizingStartup => 'Slutför uppstart...';

  @override
  String get splashReady => 'Klar';

  @override
  String get splashVersionLine => 'v1.0.6 | CruizX by KimTechTool';

  @override
  String get alertsTitle => 'Community-varningar';

  @override
  String get alertsSubtitle => 'Rapportera och visa vägfaror, kontroller och vägstatus.';

  @override
  String get convoyRequiresSignInTitle => 'Konvoj kräver inloggning';

  @override
  String get convoyRequiresSignInSubtitle => 'Logga in eller skapa konto här för att skapa konvojgrupper och se livepositioner.';

  @override
  String get signIn => 'Logga in';

  @override
  String get signUp => 'Skapa konto';

  @override
  String get signOut => 'Logga ut';

  @override
  String get signInEmailDialogTitle => 'Logga in med e-post OTP';

  @override
  String get signUpEmailDialogTitle => 'Skapa konto med e-post OTP';

  @override
  String get signInEmailFieldLabel => 'E-post';

  @override
  String get signInEmailHint => 'namn@exempel.se';

  @override
  String get signInSendOtp => 'Skicka kod';

  @override
  String get signUpSendOtp => 'Skicka kod för konto';

  @override
  String get signInOtpFieldLabel => 'OTP-kod';

  @override
  String get signInOtpHint => '6-siffrig kod';

  @override
  String get signInVerifyOtp => 'Verifiera kod';

  @override
  String get signInOtpSent => 'OTP-kod skickad till din e-post.';

  @override
  String get signUpOtpSent => 'Kod för kontoskapande skickad till din e-post.';

  @override
  String get signInOtpInvalid => 'Kunde inte verifiera OTP. Kontrollera koden och försök igen.';

  @override
  String get signUpNoAccountAction => 'Har du inget konto? Skapa ett';

  @override
  String get signUpHaveAccountAction => 'Har du redan konto? Logga in';

  @override
  String get authGenericError => 'Något gick fel. Försök igen.';

  @override
  String get authWelcomeBack => 'Välkommen tillbaka till CruizX';

  @override
  String get authRegisterSubtitle => 'Gå med i CruizX-gemenskapen';

  @override
  String get authEmailLabel => 'E-postadress';

  @override
  String get authEmailRequired => 'Ange e-postadress';

  @override
  String get authEmailInvalid => 'Ogiltig e-post';

  @override
  String get authPasswordLabel => 'Lösenord';

  @override
  String get authPasswordRequired => 'Ange lösenord';

  @override
  String get authPasswordMinLength => 'Minst 6 tecken';

  @override
  String get authConfirmPasswordLabel => 'Bekräfta lösenord';

  @override
  String get authConfirmPasswordRequired => 'Bekräfta lösenordet';

  @override
  String get authPasswordsDoNotMatch => 'Lösenorden matchar inte.';

  @override
  String get authDisplayNameLabel => 'Visningsnamn';

  @override
  String get authDisplayNameRequired => 'Ange ditt namn';

  @override
  String get authNoAccountPrompt => 'Inget konto? ';

  @override
  String get authAlreadyHaveAccountPrompt => 'Har du redan ett konto? ';

  @override
  String get authCancel => 'Avbryt';

  @override
  String get authForgotPasswordLink => 'Glömt lösenord?';

  @override
  String get authForgotPasswordTitle => 'Återställ lösenord';

  @override
  String get authForgotPasswordDescription => 'Ange din e-postadress så skickar vi en länk för att återställa ditt lösenord.';

  @override
  String get authForgotPasswordButton => 'Skicka återställningslänk';

  @override
  String get authForgotPasswordSuccess => 'Om kontot finns har vi skickat en återställningslänk till din e-post.';

  @override
  String get authResetPasswordTitle => 'Nytt lösenord';

  @override
  String get authResetPasswordDescription => 'Ange ditt nya lösenord nedan.';

  @override
  String get authNewPasswordLabel => 'Nytt lösenord';

  @override
  String get authResetPasswordButton => 'Spara lösenord';

  @override
  String get authResetPasswordSuccess => 'Ditt lösenord har ändrats.';

  @override
  String get authErrorAllFieldsRequired => 'Fyll i alla fält.';

  @override
  String get authErrorPasswordTooShort => 'Lösenordet måste vara minst 6 tecken.';

  @override
  String get authErrorConfirmEmail => 'Kolla din e-post och bekräfta kontot, logga sedan in.';

  @override
  String get authErrorEmailAndPasswordRequired => 'Fyll i e-post och lösenord.';

  @override
  String get authErrorInvalidCredentials => 'Fel e-post eller lösenord.';

  @override
  String get authErrorEmailAlreadyInUse => 'Det finns redan ett konto med den e-postadressen.';

  @override
  String get convoyRealtimeBackendMissing => 'Realtime-konvoj är inte konfigurerad ännu. Lägg till backend-konfiguration för att dela liveposition mellan användare.';

  @override
  String get convoyModeTitle => 'Konvojläge';

  @override
  String get convoyModeSubtitle => 'Skapa gruppkörning med delad destination och livepositioner.';

  @override
  String get convoyCreateButton => 'Skapa konvoj';

  @override
  String get convoyOpenButton => 'Öppna';

  @override
  String get convoyJoinButton => 'Gå med';

  @override
  String get convoyLeaveButton => 'Lämna';

  @override
  String get convoyJoinFirstHint => 'Gå med i konvojen först och tryck sedan för att öppna chat och karta.';

  @override
  String get convoyJoinByCodeTitle => 'Gå med i konvoj';

  @override
  String get convoyJoinByCodeHint => 'Ange konvojkoden du fått';

  @override
  String get convoyJoinWithCodeButton => 'Gå med';

  @override
  String get convoyJoinByCodeNotFound => 'Ingen konvoj hittades med den koden.';

  @override
  String convoyJoinByCodeSuccess(String name) {
    return 'Du gick med i $name!';
  }

  @override
  String get convoyInviteButton => 'Bjud in';

  @override
  String get convoyTabMap => 'Karta';

  @override
  String get convoyTabChat => 'Chat';

  @override
  String get convoyMapHint => 'Tryck på kartan för att lägga en delad pin.';

  @override
  String get convoyRecenterTooltip => 'Centrera och följ min position';

  @override
  String get convoyPinDialogTitle => 'Lägg till pin på kartan';

  @override
  String get convoyPinLabel => 'Pin-namn';

  @override
  String get convoyPinHint => 't.ex. Möt oss här';

  @override
  String get convoyPinAdd => 'Lägg till pin';

  @override
  String get convoyHazardPolice => 'Polis';

  @override
  String get convoyHazardRoadwork => 'Vägarbete';

  @override
  String get convoyHazardAccident => 'Olycka';

  @override
  String get convoyHazardTrafficJam => 'Kö';

  @override
  String get convoyHazardSpeedCamera => 'Fartkamera';

  @override
  String get convoyHazardCustom => 'Egen markering';

  @override
  String get convoyPoiMeetup => 'Mötesplats';

  @override
  String get convoyPoiMeetupSubtitle => 'Lägg en tydlig plats där konvojen ska samlas';

  @override
  String get convoyPoiParking => 'Parkering';

  @override
  String get convoyPoiFoodStop => 'Matstopp';

  @override
  String get convoyPoiCharging => 'Laddning';

  @override
  String get routeStopFuel => 'Bränsle';

  @override
  String get routeStopCafe => 'Café';

  @override
  String get routeStopGrocery => 'Livsmedel';

  @override
  String get convoyPoiHangout => 'Hängplats';

  @override
  String get convoyChatEmpty => 'Inga meddelanden ännu.';

  @override
  String get convoyChatPlaceholder => 'Skriv ett meddelande...';

  @override
  String get convoyChatSend => 'Skicka';

  @override
  String get convoyNameDialogTitle => 'Skapa konvoj';

  @override
  String get convoyNameFieldLabel => 'Konvojnamn';

  @override
  String get convoyNameHint => 't.ex. Fredagskörning';

  @override
  String get convoyCreateConfirm => 'Skapa';

  @override
  String get convoyCreateCancel => 'Avbryt';

  @override
  String get convoyListEmpty => 'Inga konvojer ännu. Skapa den första.';

  @override
  String get convoyListEmptyMine => 'Du har inte gått med i några konvojer ännu.';

  @override
  String get convoyFilterAll => 'Alla';

  @override
  String get convoyFilterMine => 'Mina';

  @override
  String convoyMembers(Object count) {
    return '$count medlemmar';
  }

  @override
  String get convoyMemberMe => 'Jag';

  @override
  String convoyMemberStaleTime(Object mins) {
    return '${mins}m sedan';
  }

  @override
  String convoyCreatedBy(Object leader) {
    return 'Skapad av $leader';
  }

  @override
  String get profileTitle => 'Profil & Statistik';

  @override
  String get profileNotSignedIn => 'Du är inte inloggad.';

  @override
  String get profileSignInInConvoyHint => 'Inloggning sker under fliken Konvoj.';

  @override
  String profileSignedInAs(Object name) {
    return 'Inloggad som: $name';
  }

  @override
  String get profileDefaultName => 'CruizX-förare';

  @override
  String get profileSignedIn => 'Inloggad';

  @override
  String get profileStatsTitle => 'Statistik';

  @override
  String get profileStatsConvoys => 'Körda konvojer';

  @override
  String get profileStatsTotalDistance => 'Totalt avstånd';

  @override
  String get profileStatsSpeedViolations => 'Hastighetsöverträdelser';

  @override
  String get profileVehicleTitle => 'Mitt fordon';

  @override
  String get profileVehicleElectric => 'Elfordon';

  @override
  String get profileVehicleElectricSubtitle => 'Visa laddstolpar på kartan';

  @override
  String get profileVehicleStuddedTires => 'Dubbdäck';

  @override
  String get profileVehicleStuddedTiresSubtitle => 'Undvik gator med dubbdäcksförbud';

  @override
  String get settingsTitle => 'Inställningar';

  @override
  String get settingsLanguageLabel => 'Språk';

  @override
  String get settingsLanguageSystem => 'Systemstandard';

  @override
  String get settingsLanguageEnglish => 'Engelska';

  @override
  String get settingsLanguageSwedish => 'Svenska';

  @override
  String get settingsLanguageFrench => 'Franska';

  @override
  String get settingsLanguageNorwegian => 'Norska';

  @override
  String get settingsLanguageDanish => 'Danska';

  @override
  String get settingsLanguageFinnish => 'Finska';

  @override
  String get settingsLanguageSpanish => 'Spanska';

  @override
  String get settingsCountryLabel => 'Land (trafikregler)';

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
  String get settingsCountrySpain => '🇪🇸 Spanien';

  @override
  String get settingsCountryHint => 'Hastighetsgränser och vägregler anpassas efter valt land.';

  @override
  String settingsLanguageCurrentlyUsing(Object mode) {
    return 'Använder nu: $mode';
  }

  @override
  String get settingsVehicleTypeLabel => 'Fordonstyp';

  @override
  String get settingsVehicleAtractor => 'A-traktor';

  @override
  String get settingsVehicleMopedCar => 'Mopedbil';

  @override
  String get settingsVehicleTractor => 'Traktor';

  @override
  String get settingsSpeedUnitKmh => 'km/h';

  @override
  String get settingsSpeedUnitMph => 'mph';

  @override
  String settingsMaxSpeedWithUnit(Object value, Object unit) {
    return 'Maxhastighet: $value $unit';
  }

  @override
  String get settingsProCardTitle => 'CruizX Pro';

  @override
  String get settingsProStatusActive => 'Aktiv';

  @override
  String get settingsProStatusInactive => 'Inte aktiv';

  @override
  String get settingsProDescriptionActive => 'Du har tillgång till alla Pro-funktioner.';

  @override
  String get settingsProDescriptionInactive => 'Låsa upp alla funktioner med CruizX Pro.';

  @override
  String get settingsProFeatureRoutes => 'Obegränsade rutter';

  @override
  String get settingsProFeatureConvoy => 'Obegränsat antal konvojmedlemmar';

  @override
  String get settingsProFeatureAds => 'Ingen reklam';

  @override
  String get settingsProFeatureSupport => 'Prioriterad support';

  @override
  String get settingsProSubscriptionNote => 'Prenumeration: CruizX Pro Månad (1 månad). Betalning debiteras ditt Apple-ID och förnyas automatiskt om den inte avbryts minst 24 timmar före periodens slut.';

  @override
  String settingsProPricePerMonth(Object price) {
    return '$price / månad';
  }

  @override
  String get settingsPrivacyPolicyLabel => 'Integritetspolicy';

  @override
  String get settingsTermsOfUseLabel => 'Användarvillkor (EULA)';

  @override
  String get settingsSupportLabel => 'Support';

  @override
  String get settingsLinkOpenFailed => 'Kunde inte öppna länken just nu.';

  @override
  String get settingsRestorePurchaseFailed => 'Kunde inte återställa köp.';

  @override
  String get settingsMapMarkerLabel => 'Kartmarkör';

  @override
  String get settingsMapMarkerCategoryClassic => 'Klassiska';

  @override
  String get settingsMapMarkerCategoryMicrocar => 'Mopedbil';

  @override
  String get settingsMapMarkerCategoryEpa => 'EPA';

  @override
  String get settingsMapMarkerCategoryLigier => 'Ligier';

  @override
  String get settingsMapMarkerCategoryAixam => 'Aixam';

  @override
  String get settingsMapMarkerCategoryPickup => 'Pickup';

  @override
  String get settingsMapMarkerCategoryAtractor => 'A-traktor';

  @override
  String get settingsMapMarkerCategoryTractor => 'Traktor';

  @override
  String get settingsMapMarkerArrow => 'Pil';

  @override
  String get settingsMapMarkerCompass => 'Kompass';

  @override
  String get settingsMapMarkerTriangle => 'Triangel';

  @override
  String get settingsMapMarkerDot => 'Punkt';

  @override
  String get settingsMapMarkerMicrocar => 'Mopedbil';

  @override
  String get settingsMapMarkerLigier => 'Ligier';

  @override
  String get settingsMapMarkerAixam => 'Aixam';

  @override
  String get settingsMapMarkerPickup => 'Pickup';

  @override
  String get settingsMapMarkerMini => 'MINI';

  @override
  String get settingsMapMarkerBmw => 'BMW';

  @override
  String get settingsMapMarkerTractor => 'Traktor';

  @override
  String get settingsColorRed => 'Röd';

  @override
  String get settingsColorBlue => 'Blå';

  @override
  String get settingsColorBlack => 'Svart';

  @override
  String get settingsColorWhite => 'Vit';

  @override
  String get settingsColorGold => 'Guld';

  @override
  String get settingsColorSilver => 'Silver';

  @override
  String get settingsColorGreen => 'Grön';

  @override
  String get settingsColorGraphite => 'Grafit';

  @override
  String get settingsColorYellow => 'Gul';

  @override
  String get settingsColorOrange => 'Orange';

  @override
  String get navigationTitle => 'Sväng-för-sväng-navigering';

  @override
  String get navigationSubtitle => 'Anvisningar, nästa sväng och ETA optimerat för långsamma fordon.';

  @override
  String get mapStartingGps => 'Startar GPS...';

  @override
  String get mapTapToSelectDestination => 'Tryck på kartan för att välja destination';

  @override
  String get mapAddressFieldHint => 'Sök adress (t.ex. Sveavägen 1, Stockholm)';

  @override
  String get mapSearchingAddress => 'Söker adress...';

  @override
  String get mapAddressNotFound => 'Ingen adress hittades. Försök igen.';

  @override
  String get mapAddressLookupFailed => 'Kunde inte söka adress just nu';

  @override
  String get mapLocationServicesDisabled => 'Platstjänster är avstängda';

  @override
  String get mapLocationPermissionMissing => 'Platstillstånd saknas';

  @override
  String get mapGpsActive => 'GPS aktiv';

  @override
  String get mapGpsUnavailable => 'GPS är inte tillgänglig i den här miljön';

  @override
  String get mapWaitingForGps => 'Väntar på GPS-position innan ruttberäkning';

  @override
  String get mapCalculatingRoute => 'Beräknar rutt...';

  @override
  String mapRouteReady(Object distance, Object minutes) {
    return 'Rutt klar: $distance km • $minutes min';
  }

  @override
  String get mapRouteFailed => 'Kunde inte skapa rutt just nu';

  @override
  String get mapRemaining => 'kvar';

  @override
  String get mapRouteNoRouteFound => 'Ingen rutt hittades mellan valda punkter';

  @override
  String get mapRouteProviderUnavailable => 'Rutttjänsten är inte tillgänglig just nu';

  @override
  String get mapRouteMissingApiKey => 'Routing är inte konfigurerat i backend (saknad API-nyckel)';

  @override
  String get mapRouteInvalidGeometry => 'Ruttdata från servern är ogiltig';

  @override
  String get mapRouteUnknownProvider => 'Routing-provider är inte korrekt konfigurerad';

  @override
  String get mapRouteTooFastForVehicle => 'Rutt stoppad: beräknad medelhastighet är för hög för vald fordonstyp.';

  @override
  String get mapRouteNotAllowedForVehicle => 'Ingen lagligt godkänd rutt hittades för vald fordonstyp.';

  @override
  String get routeStopSheetSubtitle => 'Närmaste stopp längs pågående rutt';

  @override
  String get routeStopNearbySubtitle => 'Närmaste alternativ omkring dig';

  @override
  String get routeStopEmpty => 'Hittade inga bra stopp nära rutten just nu.';

  @override
  String get routeStopNearbyEmpty => 'Hittade inga bra alternativ nära dig just nu.';

  @override
  String get searchSaved => 'Sparad';

  @override
  String get searchRecent => 'Nyligen';

  @override
  String get searchNew => 'Ny';

  @override
  String routeStopFromRoute(Object distance) {
    return '$distance från rutten';
  }

  @override
  String routeStopAway(Object distance) {
    return '$distance bort';
  }

  @override
  String get routeBlockedTitle => 'Rutt ej tillgänglig';

  @override
  String routeBlockedBody(Object vehicleType) {
    return 'Ingen laglig rutt hittades till destinationen för din $vehicleType. Destinationen kan ligga vid eller bara nås via vägar som inte är tillåtna för fordonstypen (t.ex. motorväg).';
  }

  @override
  String get routeBlockedOk => 'OK';

  @override
  String get routeBlockedTryOther => 'Pröva en annan destination';

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
  String get mapSimulateButton => 'Simulera';

  @override
  String get speedometerLiveSpeed => 'Aktuell hastighet';

  @override
  String speedometerMaxSpeedWithUnit(Object value, Object unit) {
    return 'Maxhastighet: $value $unit';
  }

  @override
  String get speedometerSlowDown => 'Sakta ner.';

  @override
  String get reportAlertTitle => 'Rapportera larm';

  @override
  String get reportAlertDescHint => 'Beskrivning (valfritt)';

  @override
  String get reportAlertSubmit => 'Skicka larm';

  @override
  String reportAlertNearby(Object type, Object distance) {
    return '$type · $distance m bort';
  }

  @override
  String get alertTypePolice => 'Polis';

  @override
  String get alertTypeRoadwork => 'Vägarbete';

  @override
  String get alertTypeAccident => 'Olycka';

  @override
  String get alertTypeTrafficJam => 'Trafikstockning';

  @override
  String get alertTypeSpeedCamera => 'Fartkamera';

  @override
  String get alertTypeHazard => 'Fara på vägen';

  @override
  String get alertTypeNarrowRoad => 'Smal väg';

  @override
  String get alertTypeSteepHill => 'Brant backe';

  @override
  String get alertTypeMeetup => 'Mötesplats';

  @override
  String get alertTypeParking => 'Parkering';

  @override
  String get alertTypeFoodStop => 'Matstopp';

  @override
  String get alertTypeCharging => 'Laddning';

  @override
  String get alertTypeHangout => 'Hängplats';

  @override
  String get alertGpsUnavailable => 'GPS inte tillgängligt ännu';

  @override
  String get alertMustBeLoggedIn => 'Du måste vara inloggad för att rapportera';

  @override
  String get alertsScreenSubtitle => 'Larm från andra CruizX-förare inom ~50 km. Klistra dig på tumsymboler för att bekräfta ett larm.';

  @override
  String get alertReportButton => 'Rapportera';

  @override
  String get alertTimeJustNow => 'Just nu';

  @override
  String alertTimeMinutes(Object n) {
    return '$n min sedan';
  }

  @override
  String alertTimeHours(Object n) {
    return '$n h sedan';
  }

  @override
  String get alertsEmptyTitle => 'Inga aktiva larm i närheten';

  @override
  String get alertsEmptySubtitle => 'Ser du något på vägen? Rapportera det!';

  @override
  String get alertReportQuestion => 'Vad ser du på vägen?';

  @override
  String get alertReportDescHint2 => 'Valfri beskrivning… (t.ex. \"stor gren\")';

  @override
  String get alertReportedSuccess => 'Larm rapporterat! Tack 🙏';

  @override
  String get alertReportFailed => 'Kunde inte rapportera larm just nu.';

  @override
  String get adBannerLoading => 'Annons laddas…';

  @override
  String get adBannerWaitingRetry => 'Annons väntar på nätverk… (tryck för försök igen)';

  @override
  String get mapStartNavigation => 'Starta navigation';

  @override
  String get mapEndNavigation => 'Avsluta navigation';

  @override
  String get convoyShowAll => 'Visa alla';

  @override
  String get convoyYouBadge => 'Din';

  @override
  String convoyShareCopied(Object name, Object code) {
    return 'Kopierat! Dela: \"$name\" kod: $code';
  }

  @override
  String convoyShareClipboard(Object name, Object code) {
    return 'CruizX konvoj: \"$name\" (kod: $code)';
  }

  @override
  String convoyPinMarkedBy(Object name) {
    return 'Markerad av $name';
  }

  @override
  String get convoyNavigateToPin => 'Navigera hit';

  @override
  String get convoyEtaArrived => 'Framme!';

  @override
  String convoyEtaMinutes(Object minutes, Object time) {
    return '$minutes min · $time';
  }

  @override
  String convoyEtaHours(Object hours, Object minutes, Object time) {
    return '${hours}h ${minutes}min · $time';
  }

  @override
  String get paywallTitle => 'Uppgradera till CruizX Pro';

  @override
  String get paywallSubtitle => 'Inga begränsningar. Ingen reklam. Full åtkomst.';

  @override
  String get paywallPrice => '39 kr / månad';

  @override
  String get paywallUpgradeButton => 'Uppgradera till Pro';

  @override
  String get paywallRestoreButton => 'Återställ köp';

  @override
  String paywallDisclosure(Object price) {
    return 'CruizX Pro · $price/månad · förnyas automatiskt. Avsluta när som helst i Inställningar minst 24 timmar innan förnyelse. Debiteras ditt Apple ID-konto.';
  }

  @override
  String paywallDisclosureAndroid(Object price) {
    return 'CruizX Pro · $price/månad · förnyas automatiskt. Hanteras och faktureras via Stripe. Avsluta när som helst på cruizx.com eller kontakta support.';
  }

  @override
  String get paywallFreeLabel => 'Free';

  @override
  String get paywallProLabel => 'Pro';

  @override
  String get paywallFeatureRoutes => 'Rutter per dag';

  @override
  String get paywallFreeRouteLimit => '4 rutter';

  @override
  String get paywallProRouteLimit => 'Obegränsat';

  @override
  String get paywallFeatureConvoy => 'Konvoj';

  @override
  String get paywallFreeConvoyLimit => '1 aktiv, 2 medlemmar';

  @override
  String get paywallProConvoyLimit => 'Obegränsat';

  @override
  String get paywallFeatureAds => 'Reklam';

  @override
  String get paywallFreeAds => 'Visas';

  @override
  String get paywallProAds => 'Ingen';

  @override
  String get paywallRouteLimitTitle => 'Dagsgränsen nådd';

  @override
  String get paywallRouteLimitBody => 'Free-användare kan beräkna 4 rutter per dag. Uppgradera till Pro för obegränsad navigering.';

  @override
  String get paywallConvoyLimitTitle => 'Konvojgräns nådd';

  @override
  String get paywallConvoyLimitBody => 'Free-användare kan bara vara med i 1 konvoj åt gången.';

  @override
  String get paywallMemberLimitTitle => 'Konvojen är full';

  @override
  String get paywallMemberLimitBody => 'Free-användare kan bara gå med i konvojer med färre än 2 medlemmar. Uppgradera till Pro för obegränsad åtkomst.';

  @override
  String get paywallPurchaseSuccess => 'Du är nu en Pro-användare!';

  @override
  String get paywallPurchaseFailed => 'Köpet kunde inte genomföras. Kontrollera ditt App Store-konto och försök igen.';

  @override
  String get paywallRestoreSuccess => 'Köpet återställt!';

  @override
  String get paywallLoginRequiredTitle => 'Inloggning krävs';

  @override
  String get paywallLoginRequiredBody => 'Du behöver ett konto för att köpa CruizX Pro. Skapa ett gratis konto i appen för att fortsätta.';

  @override
  String get paywallLoginRequiredAction => 'OK';

  @override
  String get paywallRestoreNotFound => 'Inget tidigare köp hittades.';

  @override
  String get profileFreePlan => 'Free-plan';

  @override
  String get profileProPlan => 'Pro-plan';

  @override
  String get profileUpgradeToPro => 'Uppgradera till Pro';

  @override
  String profileRoutesUsed(Object count, Object max) {
    return 'Rutter idag: $count / $max';
  }

  @override
  String get profileChangePhoto => 'Byt profilbild';

  @override
  String get profileTakePhoto => 'Ta foto';

  @override
  String get profileChooseFromGallery => 'Välj från galleri';

  @override
  String get profilePhotoUploadFailed => 'Kunde inte ladda upp foto';

  @override
  String get parentModeTitle => 'Föräldraläge';

  @override
  String get parentModeDescription => 'Låt en förälder följa din körning i realtid.';

  @override
  String get parentModeLoginRequired => 'Du måste vara inloggad för att använda föräldraläge.';

  @override
  String get parentModeEnable => 'Aktivera föräldraläge';

  @override
  String get parentModeEnabledSubtitle => 'Föräldrar kan följa din körning';

  @override
  String get parentModeDisabledSubtitle => 'Ingen delning aktiv';

  @override
  String get parentModeInviteCode => 'Inbjudningskod';

  @override
  String get parentModeInviteCodeSubtitle => 'Dela denna kod med din förälder för att länka deras konto.';

  @override
  String get parentModeCopyCode => 'Kopiera';

  @override
  String get parentModeShareCode => 'Dela';

  @override
  String get parentModeCodeCopied => 'Kod kopierad!';

  @override
  String get parentModeShareSubject => 'CruizX Föräldrakod';

  @override
  String parentModeShareMessage(Object code) {
    return 'Hej! Använd denna kod för att följa min körning i CruizX: $code';
  }

  @override
  String get parentModeLinkedParents => 'Länkade föräldrar';

  @override
  String get parentModeNoParentsLinked => 'Inga föräldrar länkade ännu. Dela din kod!';

  @override
  String get parentModeUnlinkTitle => 'Ta bort förälder?';

  @override
  String parentModeUnlinkMessage(Object name) {
    return 'Vill du ta bort $name som förälder? De kommer inte längre kunna följa din körning.';
  }

  @override
  String get parentModeUnlink => 'Ta bort';

  @override
  String get parentModeShareSettings => 'Vad ska delas';

  @override
  String get parentModeShareLocation => 'Dela position';

  @override
  String get parentModeShareLocationSubtitle => 'Visa var du befinner dig på kartan';

  @override
  String get parentModeShareSpeed => 'Dela hastighet';

  @override
  String get parentModeShareSpeedSubtitle => 'Visa din aktuella hastighet';

  @override
  String get parentModeAlertSettings => 'Notiser till föräldrar';

  @override
  String get parentModeSpeedAlert => 'Hastighetsvarning';

  @override
  String parentModeSpeedAlertSubtitle(Object limit) {
    return 'Meddela när hastigheten överstiger $limit km/h';
  }

  @override
  String get parentModeSpeedLimit => 'Gräns';

  @override
  String get parentModeNightAlert => 'Nattkörningsvarning';

  @override
  String parentModeNightAlertSubtitle(Object start, Object end) {
    return 'Meddela vid körning mellan kl. $start–$end';
  }

  @override
  String get cancel => 'Avbryt';

  @override
  String get login => 'Logga in';

  @override
  String get parentDashboardTitle => 'Föräldra-dashboard';

  @override
  String get parentDashboardMapTab => 'Karta';

  @override
  String get parentDashboardAlertsTab => 'Larm';

  @override
  String get parentDashboardAddChild => 'Lägg till barn';

  @override
  String get parentDashboardOnline => 'Online';

  @override
  String get parentDashboardOffline => 'Offline';

  @override
  String get parentDashboardNoAlerts => 'Inga larm de senaste 24 timmarna';

  @override
  String get parentDashboardNoChildren => 'Inga barn länkade ännu';

  @override
  String get parentDashboardNoChildrenHint => 'Lägg till ett barn genom att ange deras inbjudningskod från CruizX Föräldraläge.';

  @override
  String get parentDashboardEnterCode => 'Ange inbjudningskod';

  @override
  String get parentDashboardEnterCodeHint => 'Be ditt barn dela sin 6-tecken inbjudningskod från Föräldraläge-inställningarna.';

  @override
  String get parentDashboardLink => 'Länka';

  @override
  String get parentDashboardLinkSuccess => 'Länkning lyckades!';

  @override
  String get parentDashboardLinkFailed => 'Kunde inte hitta barn med den koden. Kontrollera koden och försök igen.';

  @override
  String get parentDashboardLinkSelf => 'Du kan inte länka till ditt eget konto. Be ditt barn dela sin kod från sitt konto.';

  @override
  String get parentDashboardSpeedingAlert => 'Hastighetsvarning';

  @override
  String parentDashboardSpeedingDetail(Object name, Object speed, Object limit) {
    return '$name körde i $speed km/h (gräns: $limit km/h)';
  }

  @override
  String get parentDashboardNightAlert => 'Nattkörning';

  @override
  String parentDashboardNightDetail(Object name) {
    return '$name kör på natten';
  }

  @override
  String get parentDashboardViewChild => 'Visa som förälder';

  @override
  String get settingsVoiceNavigation => 'Röstnavigering';

  @override
  String get settingsVoiceNavigationSubtitle => 'Läs upp svänginstruktioner';

  @override
  String get voiceTurnLeft => 'Sväng vänster';

  @override
  String get voiceTurnRight => 'Sväng höger';

  @override
  String get voiceTurnSharpLeft => 'Sväng skarpt vänster';

  @override
  String get voiceTurnSharpRight => 'Sväng skarpt höger';

  @override
  String get voiceTurnSlightLeft => 'Sväng svagt vänster';

  @override
  String get voiceTurnSlightRight => 'Sväng svagt höger';

  @override
  String get voiceContinue => 'Fortsätt rakt fram';

  @override
  String get voiceRoundabout => 'Kör in i rondellen';

  @override
  String get voiceDestination => 'Du har nått din destination';

  @override
  String voiceInMeters(Object meters) {
    return 'Om $meters meter';
  }

  @override
  String voiceInKm(Object km) {
    return 'Om $km kilometer';
  }

  @override
  String get mfaSetupTitle => 'Aktivera tvåfaktorsautentisering';

  @override
  String get mfaSetupSubtitle => 'Skanna QR-koden med en autentiseringsapp som Google Authenticator eller Authy';

  @override
  String get mfaScanQr => 'Skanna koden ovan och ange den 6-siffriga koden nedan';

  @override
  String get mfaVerifyButton => 'Verifiera';

  @override
  String get mfaVerifyTitle => 'Tvåfaktorsautentisering';

  @override
  String get mfaVerifySubtitle => 'Ange den 6-siffriga koden från din autentiseringsapp';

  @override
  String get mfaInvalidCode => 'Felaktig kod, försök igen';

  @override
  String get mfaCancel => 'Avbryt och logga ut';

  @override
  String get mfaProfileTitle => 'Tvåfaktorsautentisering';

  @override
  String get mfaStatusOn => 'Aktiverad — ditt konto är skyddat';

  @override
  String get mfaStatusOff => 'Inaktiverad';

  @override
  String get mfaTurnOn => 'Aktivera';

  @override
  String get mfaTurnOff => 'Stäng av';

  @override
  String get mfaDisableTitle => 'Stäng av 2FA?';

  @override
  String get mfaDisableBody => 'Ditt konto blir mindre säkert utan tvåfaktorsautentisering.';

  @override
  String get mfaDisableConfirm => 'Stäng av';

  @override
  String get mfaShowManualKey => 'Kan du inte skanna? Visa nyckel manuellt';

  @override
  String get mfaHideManualKey => 'Dölj manuell nyckel';

  @override
  String get mfaKeyCopied => 'Nyckel kopierad';

  @override
  String get mfaRecommendTitle => 'Skydda ditt konto';

  @override
  String get mfaRecommendBody => 'Vi rekommenderar att du aktiverar tvåfaktorsautentisering för att skydda ditt konto. Du kan använda en autentiseringsapp som Google Authenticator eller Authy.';

  @override
  String get mfaRecommendSetup => 'Aktivera nu';

  @override
  String get mfaRecommendLater => 'Senare';

  @override
  String get favHome => 'Hem';

  @override
  String get favSchool => 'Skola';

  @override
  String get favWork => 'Jobb';

  @override
  String get favAddTitle => 'Spara plats';

  @override
  String get favLabelHint => 'Namn (t.ex. Kompis)';

  @override
  String get favSaved => 'Plats sparad';

  @override
  String get favDeleted => 'Plats borttagen';

  @override
  String favDeleteConfirm(Object name) {
    return 'Ta bort $name?';
  }

  @override
  String favSetAs(Object type) {
    return 'Spara som $type';
  }

  @override
  String get favCustom => 'Annan favorit';

  @override
  String get ttsVoiceHint => 'Tips: Ladda ner bättre röster i Inställningar → Hjälpmedel → Uppläsning och tal → Röster';

  @override
  String get ttsVoiceHintDismiss => 'OK';
}
