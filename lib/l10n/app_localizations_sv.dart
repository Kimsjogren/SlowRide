// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'SlowRide';

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
  String get splashVersionLine => 'v1.0.0 | SlowRide by KimTechTool';

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
  String get convoyRealtimeBackendMissing => 'Realtime-konvoj är inte konfigurerad ännu. Lägg till backend-konfiguration för att dela liveposition mellan användare.';

  @override
  String get convoyModeTitle => 'Konvojläge';

  @override
  String get convoyModeSubtitle => 'Skapa gruppkörning med delad destination och livepositioner.';

  @override
  String get convoyCreateButton => 'Skapa konvoj';

  @override
  String get convoyJoinButton => 'Gå med';

  @override
  String get convoyLeaveButton => 'Lämna';

  @override
  String get convoyJoinFirstHint => 'Gå med i konvojen först och tryck sedan för att öppna chat och karta.';

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
  String get alertGpsUnavailable => 'GPS inte tillgängligt ännu';

  @override
  String get alertMustBeLoggedIn => 'Du måste vara inloggad för att rapportera';

  @override
  String get alertsScreenSubtitle => 'Larm från andra SlowRiders inom ~50 km. Klistra dig på tumsymboler för att bekräfta ett larm.';

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
}
