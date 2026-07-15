// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppLocalizationsFi extends AppLocalizations {
  AppLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get appTitle => 'CruizX';

  @override
  String get navMap => 'Kartta';

  @override
  String get navAlerts => 'Hälytykset';

  @override
  String get navConvoy => 'Saattue';

  @override
  String get navProfile => 'Profiili';

  @override
  String get navSettings => 'Asetukset';

  @override
  String get splashPreparingStartup => 'Valmistellaan käynnistystä...';

  @override
  String get splashLoadingCoreModules => 'Ladataan ydinmoduuleja...';

  @override
  String get splashInitializingAccountSession => 'Alustetaan tili-istuntoa...';

  @override
  String get splashLoadingPreferences => 'Ladataan asetuksia...';

  @override
  String get splashFinalizingStartup => 'Viimeistellään käynnistystä...';

  @override
  String get splashReady => 'Valmis';

  @override
  String get splashVersionLine => 'v1.1.2 | CruizX by KimTechTool';

  @override
  String get alertsTitle => 'Yhteisön hälytykset';

  @override
  String get alertsSubtitle => 'Ilmoita ja tarkastele tievaaroja, tarkastuksia ja tieolosuhteita.';

  @override
  String get convoyRequiresSignInTitle => 'Saattue vaatii kirjautumisen';

  @override
  String get convoyRequiresSignInSubtitle => 'Kirjaudu sisään tai luo tili täällä luodaksesi saattueryhmiä ja nähdäksesi live-sijainnit.';

  @override
  String get signIn => 'Kirjaudu sisään';

  @override
  String get signUp => 'Luo tili';

  @override
  String get signOut => 'Kirjaudu ulos';

  @override
  String get signInEmailDialogTitle => 'Kirjaudu sähköposti-OTP:llä';

  @override
  String get signUpEmailDialogTitle => 'Luo tili sähköposti-OTP:llä';

  @override
  String get signInEmailFieldLabel => 'Sähköposti';

  @override
  String get signInEmailHint => 'nimi@esimerkki.fi';

  @override
  String get signInSendOtp => 'Lähetä koodi';

  @override
  String get signUpSendOtp => 'Lähetä tilikoodi';

  @override
  String get signInOtpFieldLabel => 'OTP-koodi';

  @override
  String get signInOtpHint => '6-numeroinen koodi';

  @override
  String get signInVerifyOtp => 'Vahvista koodi';

  @override
  String get signInOtpSent => 'OTP-koodi lähetetty sähköpostiisi.';

  @override
  String get signUpOtpSent => 'Tilin luontikoodi lähetetty sähköpostiisi.';

  @override
  String get signInOtpInvalid => 'OTP-koodia ei voitu vahvistaa. Tarkista koodi ja yritä uudelleen.';

  @override
  String get signUpNoAccountAction => 'Ei tiliä? Luo tili';

  @override
  String get signUpHaveAccountAction => 'Onko sinulla jo tili? Kirjaudu sisään';

  @override
  String get authGenericError => 'Jokin meni pieleen. Yritä uudelleen.';

  @override
  String get authWelcomeBack => 'Tervetuloa takaisin CruizX:ään';

  @override
  String get authRegisterSubtitle => 'Liity CruizX-yhteisöön';

  @override
  String get authEmailLabel => 'Sähköpostiosoite';

  @override
  String get authEmailRequired => 'Syötä sähköpostiosoitteesi';

  @override
  String get authEmailInvalid => 'Virheellinen sähköposti';

  @override
  String get authPasswordLabel => 'Salasana';

  @override
  String get authPasswordRequired => 'Syötä salasanasi';

  @override
  String get authPasswordMinLength => 'Vähintään 6 merkkiä';

  @override
  String get authConfirmPasswordLabel => 'Vahvista salasana';

  @override
  String get authConfirmPasswordRequired => 'Vahvista salasanasi';

  @override
  String get authPasswordsDoNotMatch => 'Salasanat eivät täsmää.';

  @override
  String get authDisplayNameLabel => 'Näyttönimi';

  @override
  String get authDisplayNameRequired => 'Syötä nimesi';

  @override
  String get authNoAccountPrompt => 'Ei tiliä? ';

  @override
  String get authAlreadyHaveAccountPrompt => 'Onko sinulla jo tili? ';

  @override
  String get authCancel => 'Peruuta';

  @override
  String get authForgotPasswordLink => 'Unohditko salasanan?';

  @override
  String get authForgotPasswordTitle => 'Palauta salasana';

  @override
  String get authForgotPasswordDescription => 'Syötä sähköpostiosoitteesi, niin lähetämme sinulle linkin salasanan palauttamiseksi.';

  @override
  String get authForgotPasswordButton => 'Lähetä palautuslinkki';

  @override
  String get authForgotPasswordSuccess => 'Jos tili on olemassa, lähetimme palautuslinkin sähköpostiisi.';

  @override
  String get authResetPasswordTitle => 'Uusi salasana';

  @override
  String get authResetPasswordDescription => 'Syötä uusi salasanasi alle.';

  @override
  String get authNewPasswordLabel => 'Uusi salasana';

  @override
  String get authResetPasswordButton => 'Tallenna salasana';

  @override
  String get authResetPasswordSuccess => 'Salasanasi on vaihdettu.';

  @override
  String get authErrorAllFieldsRequired => 'Kaikki kentät ovat pakollisia.';

  @override
  String get authErrorPasswordTooShort => 'Salasanan on oltava vähintään 6 merkkiä.';

  @override
  String get authErrorConfirmEmail => 'Tarkista sähköpostisi vahvistaaksesi tilisi ja kirjaudu sitten sisään.';

  @override
  String get authErrorEmailAndPasswordRequired => 'Syötä sähköposti ja salasana.';

  @override
  String get authErrorInvalidCredentials => 'Väärä sähköposti tai salasana.';

  @override
  String get authErrorEmailAlreadyInUse => 'Tällä sähköpostilla on jo tili.';

  @override
  String get convoyRealtimeBackendMissing => 'Reaaliaikaista saattuetta ei ole vielä määritetty. Lisää backend-konfiguraatio jakaaksesi live-sijainnit käyttäjien kesken.';

  @override
  String get convoyModeTitle => 'Saattuetila';

  @override
  String get convoyModeSubtitle => 'Luo ryhmäajo jaetulla määränpäällä ja live-sijainneilla.';

  @override
  String get convoyCreateButton => 'Luo saattue';

  @override
  String get publicGatheringsTitle => 'Julkiset tapaamiset';

  @override
  String get publicGatheringsSubtitle => 'Löydä kokoontumispaikka, liity julkisesti ja päätä itse, näytetäänkö reaaliaikainen sijaintisi.';

  @override
  String get publicGatheringsMineTab => 'Omat';

  @override
  String get publicGatheringsPublicTab => 'Julkiset';

  @override
  String get publicGatheringsEmpty => 'Aktiivisia julkisia tapaamisia ei ole juuri nyt.';

  @override
  String get publicGatheringCreateButton => 'Luo julkinen tapaaminen';

  @override
  String get publicGatheringCreateTitle => 'Uusi julkinen tapaaminen';

  @override
  String get publicGatheringPlaceHint => 'Kokoontumispaikka, esim. tori';

  @override
  String get publicGatheringLocationExplanation => 'Tapaaminen sijoitetaan nykyiseen sijaintiisi ja on aktiivinen 6 tuntia. Reaaliaikaisen sijainnin jakaminen on vapaaehtoista.';

  @override
  String get publicGatheringLocationRequired => 'Kokoontumispaikan asettaminen edellyttää sijaintilupaa.';

  @override
  String get publicGatheringPublish => 'Julkaise';

  @override
  String get publicGatheringStartSharing => 'Jaa reaaliaikainen sijaintini';

  @override
  String get publicGatheringStopSharing => 'Lopeta reaaliaikaisen sijaintini jakaminen';

  @override
  String get convoyOpenButton => 'Avaa';

  @override
  String get convoyJoinButton => 'Liity';

  @override
  String get convoyLeaveButton => 'Poistu';

  @override
  String get convoyJoinFirstHint => 'Liity ensin saattueeseen ja avaa sitten chat ja kartta napauttamalla.';

  @override
  String get convoyJoinByCodeTitle => 'Liity saattueeseen';

  @override
  String get convoyJoinByCodeHint => 'Syötä saamasi saattueen koodi';

  @override
  String get convoyJoinWithCodeButton => 'Liity';

  @override
  String get convoyJoinByCodeNotFound => 'Saattuetta ei löytynyt tällä koodilla.';

  @override
  String convoyJoinByCodeSuccess(String name) {
    return 'Liityit saattueeseen $name!';
  }

  @override
  String get convoyInviteButton => 'Kutsu';

  @override
  String get convoyTabMap => 'Kartta';

  @override
  String get convoyTabChat => 'Chat';

  @override
  String get convoyMapHint => 'Napauta karttaa asettaaksesi jaetun merkin.';

  @override
  String get convoyRecenterTooltip => 'Keskitä ja seuraa sijaintiani';

  @override
  String get convoyPinDialogTitle => 'Lisää karttamerkki';

  @override
  String get convoyPinLabel => 'Merkin nimi';

  @override
  String get convoyPinHint => 'esim. Tavataan täällä';

  @override
  String get convoyPinAdd => 'Lisää merkki';

  @override
  String get convoyHazardPolice => 'Poliisi';

  @override
  String get convoyHazardRoadwork => 'Tietyö';

  @override
  String get convoyHazardAccident => 'Onnettomuus';

  @override
  String get convoyHazardTrafficJam => 'Ruuhka';

  @override
  String get convoyHazardSpeedCamera => 'Nopeuskamera';

  @override
  String get convoyHazardCustom => 'Mukautettu merkki';

  @override
  String get convoyPoiMeetup => 'Tapaamispaikka';

  @override
  String get convoyPoiMeetupSubtitle => 'Merkitse selkeä paikka, johon saattue kokoontuu';

  @override
  String get convoyPoiParking => 'Pysäköinti';

  @override
  String get convoyPoiFoodStop => 'Ruokatauko';

  @override
  String get convoyPoiCharging => 'Lataus';

  @override
  String get routeStopFuel => 'Polttoaine';

  @override
  String get routeStopCafe => 'Kahvila';

  @override
  String get routeStopGrocery => 'Ruokakauppa';

  @override
  String get convoyPoiHangout => 'Kokoontumispaikka';

  @override
  String get convoyChatEmpty => 'Ei viestejä vielä.';

  @override
  String get convoyChatPlaceholder => 'Kirjoita viesti...';

  @override
  String get convoyChatSend => 'Lähetä';

  @override
  String get convoyNameDialogTitle => 'Luo saattue';

  @override
  String get convoyNameFieldLabel => 'Saattueen nimi';

  @override
  String get convoyNameHint => 'esim. Perjantai-illan ajelu';

  @override
  String get convoyCreateConfirm => 'Luo';

  @override
  String get convoyCreateCancel => 'Peruuta';

  @override
  String get convoyListEmpty => 'Ei saattueita vielä. Luo ensimmäinen.';

  @override
  String get convoyListEmptyMine => 'Et ole vielä liittynyt yhteenkään saattueeseen.';

  @override
  String get convoyFilterAll => 'Kaikki';

  @override
  String get convoyFilterMine => 'Omat';

  @override
  String convoyMembers(Object count) {
    return '$count jäsentä';
  }

  @override
  String get convoyMemberMe => 'Minä';

  @override
  String convoyMemberStaleTime(Object mins) {
    return '$mins min sitten';
  }

  @override
  String convoyCreatedBy(Object leader) {
    return 'Luonut $leader';
  }

  @override
  String get profileTitle => 'Profiili & Tilastot';

  @override
  String get profileNotSignedIn => 'Et ole kirjautuneena.';

  @override
  String get profileSignInInConvoyHint => 'Kirjautuminen on saatavilla Saattue-välilehdellä.';

  @override
  String profileSignedInAs(Object name) {
    return 'Kirjautuneena: $name';
  }

  @override
  String get profileDefaultName => 'CruizX-kuljettaja';

  @override
  String get profileSignedIn => 'Kirjautunut';

  @override
  String get profileStatsTitle => 'Tilastot';

  @override
  String get profileStatsConvoys => 'Ajetut saattueet';

  @override
  String get profileStatsTotalDistance => 'Kokonaismatka';

  @override
  String get profileStatsSpeedViolations => 'Ylinopeudet';

  @override
  String get profileVehicleTitle => 'Ajoneuvoni';

  @override
  String get profileVehicleElectric => 'Sähköajoneuvo';

  @override
  String get profileVehicleElectricSubtitle => 'Näytä latausasemat kartalla';

  @override
  String get profileVehicleStuddedTires => 'Nastarenkaat';

  @override
  String get profileVehicleStuddedTiresSubtitle => 'Vältä katuja, joilla nastarengas on kielletty';

  @override
  String get settingsTitle => 'Asetukset';

  @override
  String get settingsLanguageLabel => 'Kieli';

  @override
  String get settingsLanguageSystem => 'Järjestelmän oletus';

  @override
  String get settingsLanguageEnglish => 'Englanti';

  @override
  String get settingsLanguageSwedish => 'Ruotsi';

  @override
  String get settingsLanguageFrench => 'Ranska';

  @override
  String get settingsLanguageNorwegian => 'Norja';

  @override
  String get settingsLanguageDanish => 'Tanska';

  @override
  String get settingsLanguageFinnish => 'Suomi';

  @override
  String get settingsLanguageSpanish => 'Espanja';

  @override
  String get settingsCountryLabel => 'Maa (liikennesäännöt)';

  @override
  String get settingsCountrySweden => '🇸🇪 Ruotsi';

  @override
  String get settingsCountryNorway => '🇳🇴 Norja';

  @override
  String get settingsCountryDenmark => '🇩🇰 Tanska';

  @override
  String get settingsCountryFinland => '🇫🇮 Suomi';

  @override
  String get settingsCountryFrance => '🇫🇷 Ranska';

  @override
  String get settingsCountrySpain => '🇪🇸 Espanja';

  @override
  String get settingsCountryUnitedKingdom => '🇬🇧 Yhdistynyt kuningaskunta';

  @override
  String get settingsCountryHint => 'Nopeusrajoitukset ja liikennesäännöt mukautuvat valitun maan mukaan.';

  @override
  String settingsLanguageCurrentlyUsing(Object mode) {
    return 'Käytössä: $mode';
  }

  @override
  String get settingsVehicleTypeLabel => 'Ajoneuvotyyppi';

  @override
  String get settingsVehicleAtractor => 'A-traktori';

  @override
  String get settingsVehicleLowVehicle => 'Matala ajoneuvo';

  @override
  String get settingsVehicleMopedCar => 'Mopoauto';

  @override
  String get settingsVehicleTractor => 'Traktori';

  @override
  String get settingsSpeedUnitKmh => 'km/h';

  @override
  String get settingsSpeedUnitMph => 'mph';

  @override
  String settingsMaxSpeedWithUnit(Object value, Object unit) {
    return 'Maksiminopeus: $value $unit';
  }

  @override
  String get settingsProCardTitle => 'CruizX Pro';

  @override
  String get settingsProStatusActive => 'Aktiivinen';

  @override
  String get settingsProStatusInactive => 'Ei aktiivinen';

  @override
  String get settingsProDescriptionActive => 'Sinulla on pääsy kaikkiin Pro-ominaisuuksiin.';

  @override
  String get settingsProDescriptionInactive => 'Avaa kaikki ominaisuudet CruizX Prolla.';

  @override
  String get settingsProFeatureRoutes => 'Rajattomat reitit';

  @override
  String get settingsProFeatureConvoy => 'Rajaton saattue';

  @override
  String get settingsProFeatureAds => 'Ei mainoksia';

  @override
  String get settingsProFeatureSupport => 'Ensisijainen tuki';

  @override
  String get settingsProSubscriptionNote => 'Tilaus: CruizX Pro Kuukausittain (1 kuukausi). Maksu veloitetaan Apple ID:ltäsi ja uusitaan automaattisesti, ellei sitä peruuteta vähintään 24 tuntia ennen jakson päättymistä.';

  @override
  String settingsProPricePerMonth(Object price) {
    return '$price / kuukausi';
  }

  @override
  String settingsProPriceOneTime(Object price) {
    return '$price';
  }

  @override
  String get settingsProOneTimeNote => 'Kertaosto: CruizX Pro (elinikäinen). Maksu veloitetaan kerran Apple ID -tililtäsi. Ei tilausta eikä automaattista uusimista.';

  @override
  String get settingsPrivacyPolicyLabel => 'Tietosuojakäytäntö';

  @override
  String get settingsTermsOfUseLabel => 'Käyttöehdot (EULA)';

  @override
  String get settingsSupportLabel => 'Tuki';

  @override
  String get settingsLinkOpenFailed => 'Linkkiä ei voitu avata juuri nyt.';

  @override
  String get settingsRestorePurchaseFailed => 'Ostoa ei voitu palauttaa.';

  @override
  String get settingsMapMarkerLabel => 'Karttamerkki';

  @override
  String get settingsMapMarkerCategoryClassic => 'Klassiset';

  @override
  String get settingsMapMarkerCategoryMicrocar => 'Mopoauto';

  @override
  String get settingsMapMarkerCategoryEpa => 'EPA';

  @override
  String get settingsMapMarkerCategoryLigier => 'Ligier';

  @override
  String get settingsMapMarkerCategoryAixam => 'Aixam';

  @override
  String get settingsMapMarkerCategoryPickup => 'Pickup';

  @override
  String get settingsMapMarkerCategoryAtractor => 'A-traktori';

  @override
  String get settingsMapMarkerCategoryTractor => 'Traktori';

  @override
  String get settingsMapMarkerArrow => 'Nuoli';

  @override
  String get settingsMapMarkerCompass => 'Kompassi';

  @override
  String get settingsMapMarkerTriangle => 'Kolmio';

  @override
  String get settingsMapMarkerDot => 'Piste';

  @override
  String get settingsMapMarkerEpa => 'EPA';

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
  String get settingsColorRed => 'Punainen';

  @override
  String get settingsColorBlue => 'Sininen';

  @override
  String get settingsColorBlack => 'Musta';

  @override
  String get settingsColorWhite => 'Valkoinen';

  @override
  String get settingsColorGold => 'Kulta';

  @override
  String get settingsColorSilver => 'Hopea';

  @override
  String get settingsColorGreen => 'Vihreä';

  @override
  String get settingsColorGraphite => 'Grafiitti';

  @override
  String get settingsColorYellow => 'Keltainen';

  @override
  String get settingsColorOrange => 'Oranssi';

  @override
  String get settingsColorPink => 'Vaaleanpunainen';

  @override
  String get navigationTitle => 'Käännös käännökseltä -navigointi';

  @override
  String get navigationSubtitle => 'Reittiohjeet, seuraava käännös ja saapumisaika optimoitu hitaille ajoneuvoille.';

  @override
  String get mapStartingGps => 'Käynnistetään GPS...';

  @override
  String get mapTapToSelectDestination => 'Napauta karttaa valitaksesi määränpään';

  @override
  String get mapAddressFieldHint => 'Hae osoite (esim. Mannerheimintie 1, Helsinki)';

  @override
  String get mapSearchingAddress => 'Haetaan osoitetta...';

  @override
  String get mapAddressNotFound => 'Osoitetta ei löytynyt. Yritä uudelleen.';

  @override
  String get mapAddressLookupFailed => 'Osoitetta ei voitu hakea juuri nyt';

  @override
  String get mapLocationServicesDisabled => 'Sijaintipalvelut ovat pois käytöstä';

  @override
  String get mapLocationPermissionMissing => 'Sijaintilupa puuttuu';

  @override
  String get mapGpsActive => 'GPS aktiivinen';

  @override
  String get mapGpsUnavailable => 'GPS ei ole käytettävissä tässä ympäristössä';

  @override
  String get mapWaitingForGps => 'Odotetaan GPS-sijaintia ennen reitin laskentaa';

  @override
  String get mapCalculatingRoute => 'Lasketaan reittiä...';

  @override
  String mapRouteReady(Object distance, Object minutes) {
    return 'Reitti valmis: $distance km • $minutes min';
  }

  @override
  String get mapRouteFailed => 'Reittiä ei voitu luoda juuri nyt';

  @override
  String get mapRemaining => 'jäljellä';

  @override
  String get mapRouteNoRouteFound => 'Reittiä ei löytynyt valittujen pisteiden välille';

  @override
  String get mapRouteProviderUnavailable => 'Reittipalvelu ei ole käytettävissä juuri nyt';

  @override
  String get mapRouteMissingApiKey => 'Reittiä ei ole määritetty backendissä (API-avain puuttuu)';

  @override
  String get mapRouteInvalidGeometry => 'Reittidata palvelimelta on virheellinen';

  @override
  String get mapRouteUnknownProvider => 'Reittitarjoaja ei ole oikein määritetty';

  @override
  String get mapRouteTooFastForVehicle => 'Reitti hylätty: arvioitu keskinopeus on liian suuri tälle ajoneuvotyypille.';

  @override
  String get mapRouteNotAllowedForVehicle => 'Laillisesti hyväksyttävää reittiä ei löytynyt tälle ajoneuvotyypille.';

  @override
  String get routeStopSheetSubtitle => 'Lähimmät pysähdykset nykyisen reitin varrella';

  @override
  String get routeStopNearbySubtitle => 'Lähimmät vaihtoehdot ympärilläsi';

  @override
  String get routeStopEmpty => 'Reitin läheltä ei löytynyt hyviä pysähdyksiä juuri nyt.';

  @override
  String get routeStopNearbyEmpty => 'Läheltäsi ei löytynyt hyviä vaihtoehtoja juuri nyt.';

  @override
  String get searchSaved => 'Tallennetut';

  @override
  String get searchRecent => 'Viimeisimmät';

  @override
  String get searchNew => 'Uusi';

  @override
  String routeStopFromRoute(Object distance) {
    return '$distance reitiltä';
  }

  @override
  String routeStopAway(Object distance) {
    return '$distance päässä';
  }

  @override
  String get routeBlockedTitle => 'Reitti ei saatavilla';

  @override
  String routeBlockedBody(Object vehicleType) {
    return 'Laillista reittiä kohteeseen ei löytynyt ajoneuvollesi $vehicleType. Kohde saattaa sijaita teiden varrella tai on saavutettavissa vain teillä, jotka eivät ole sallittuja tälle ajoneuvotyypille (esim. moottoritie).';
  }

  @override
  String get routeBlockedOk => 'OK';

  @override
  String get routeBlockedTryOther => 'Kokeile toista kohdetta';

  @override
  String get routeFallbackTitle => 'Varmistamaton reitti löytyi';

  @override
  String routeFallbackBody(Object vehicleType) {
    return 'Löysimme mahdollisen reitin, mutta sitä ei voitu täysin varmistaa ajoneuvollesi $vehicleType. Se voi sisältää teitä, jotka pitää tarkistaa. Noudata aina liikennemerkkejä ja paikallisia sääntöjä.';
  }

  @override
  String get routeFallbackCancel => 'Peruuta';

  @override
  String get routeFallbackUse => 'Näytä silti';

  @override
  String get routeFallbackActive => 'Varmistamaton reitti – noudata aina merkkejä';

  @override
  String get routeOptionsTitle => 'Valitse reitti';

  @override
  String get routeOptionRecommended => 'Suositeltu';

  @override
  String get routeOptionRecommendedSubtitle => 'Varmistettu CruizX-sääntöjen mukaan valitulle ajoneuvolle.';

  @override
  String get routeOptionAlternative => 'Vaihtoehtoinen reitti';

  @override
  String get routeOptionAlternativeSubtitle => 'Laillinen reitti — eri teitä tai hieman pidempi.';

  @override
  String get routeOptionUnverified => 'Varmistamaton vaihtoehtoinen reitti';

  @override
  String routeOptionUnverifiedSubtitle(Object vehicleType) {
    return 'Ei voida täysin varmistaa ajoneuvollesi $vehicleType. Tarkista liikennemerkit ennen ajoa.';
  }

  @override
  String get routeOptionChoose => 'Valitse';

  @override
  String routeOptionMetrics(Object km, Object minutes) {
    return '$km km · $minutes min';
  }

  @override
  String get routeOptionWarningFooter => 'CruizX ei koskaan hyväksy kiellettyjä teitä automaattisesti. Noudata aina merkkejä ja paikallisia sääntöjä.';

  @override
  String get mapModeLabel2d => '2D';

  @override
  String get mapModeLabel3d => '3D';

  @override
  String mapManeuverInDistance(Object distance) {
    return '$distance päässä';
  }

  @override
  String mapManeuverTowardRoad(Object road) {
    return 'Kohti $road';
  }

  @override
  String get mapSimulateButton => 'Simuloi';

  @override
  String get speedometerLiveSpeed => 'Nykyinen nopeus';

  @override
  String speedometerMaxSpeedWithUnit(Object value, Object unit) {
    return 'Maksiminopeus: $value $unit';
  }

  @override
  String get speedometerSlowDown => 'Hidasta.';

  @override
  String get reportAlertTitle => 'Ilmoita hälytys';

  @override
  String get reportAlertDescHint => 'Kuvaus (valinnainen)';

  @override
  String get reportAlertSubmit => 'Lähetä hälytys';

  @override
  String reportAlertNearby(Object type, Object distance) {
    return '$type · $distance m edessä';
  }

  @override
  String get alertTypeRoadClosure => 'Tiesulku';

  @override
  String get alertTypePolice => 'Poliisi';

  @override
  String get alertTypeRoadwork => 'Tietyö';

  @override
  String get alertTypeAccident => 'Onnettomuus';

  @override
  String get alertTypeTrafficJam => 'Ruuhka';

  @override
  String get alertTypeSpeedCamera => 'Nopeuskamera';

  @override
  String get alertTypeHazard => 'Vaara';

  @override
  String get alertTypeNarrowRoad => 'Kapea tie';

  @override
  String get alertTypeSteepHill => 'Jyrkkä mäki';

  @override
  String get alertTypeSpeedBump => 'Korkea hidastetöyssy';

  @override
  String get alertTypeMeetup => 'Tapaamispaikka';

  @override
  String get alertTypeParking => 'Pysäköinti';

  @override
  String get alertTypeFoodStop => 'Ruokatauko';

  @override
  String get alertTypeCharging => 'Lataus';

  @override
  String get alertTypeHangout => 'Kokoontumispaikka';

  @override
  String get alertGpsUnavailable => 'GPS ei ole vielä käytettävissä';

  @override
  String get alertMustBeLoggedIn => 'Sinun on oltava kirjautuneena ilmoittaaksesi';

  @override
  String get alertsScreenSubtitle => 'Trafikverketin ja CruizX-kuljettajien reaaliaikaiset tiedot ~50 km säteellä. Vahvista käyttäjähälytys peukalolla.';

  @override
  String get alertReportButton => 'Ilmoita';

  @override
  String get alertTimeJustNow => 'Juuri nyt';

  @override
  String alertTimeMinutes(Object n) {
    return '$n min sitten';
  }

  @override
  String alertTimeHours(Object n) {
    return '$n t sitten';
  }

  @override
  String get alertsEmptyTitle => 'Ei aktiivisia hälytyksiä lähellä';

  @override
  String get alertsEmptySubtitle => 'Näetkö jotain tiellä? Ilmoita siitä!';

  @override
  String get alertReportQuestion => 'Mitä näet tiellä?';

  @override
  String get alertReportDescHint2 => 'Valinnainen kuvaus… (esim. \"iso oksa\")';

  @override
  String get alertReportedSuccess => 'Hälytys ilmoitettu! Kiitos 🙏';

  @override
  String get alertReportFailed => 'Hälytystä ei voitu ilmoittaa juuri nyt.';

  @override
  String get adBannerLoading => 'Ladataan mainosta…';

  @override
  String get adBannerWaitingRetry => 'Mainos odottaa verkkoa… (napauta yrittääksesi uudelleen)';

  @override
  String get mapStartNavigation => 'Aloita navigointi';

  @override
  String get mapEndNavigation => 'Lopeta navigointi';

  @override
  String get convoyShowAll => 'Näytä kaikki';

  @override
  String get convoyYouBadge => 'Sinä';

  @override
  String convoyShareCopied(Object name, Object code) {
    return 'Kopioitu! Jaa: \"$name\" koodi: $code';
  }

  @override
  String convoyShareClipboard(Object name, Object code) {
    return 'CruizX-saattue: \"$name\" (koodi: $code)';
  }

  @override
  String convoyPinMarkedBy(Object name) {
    return 'Merkinnyt $name';
  }

  @override
  String get convoyNavigateToPin => 'Navigoi tähän';

  @override
  String get convoyEtaArrived => 'Perillä!';

  @override
  String convoyEtaMinutes(Object minutes, Object time) {
    return '$minutes min · $time';
  }

  @override
  String convoyEtaHours(Object hours, Object minutes, Object time) {
    return '${hours}t ${minutes}min · $time';
  }

  @override
  String get paywallTitle => 'Päivitä CruizX Prohon';

  @override
  String get paywallSubtitle => 'Ei rajoituksia. Ei mainoksia. Täysi pääsy.';

  @override
  String get paywallPrice => '3,49 € / kuukausi';

  @override
  String get paywallUpgradeButton => 'Päivitä Prohon';

  @override
  String get paywallRestoreButton => 'Palauta osto';

  @override
  String paywallDisclosure(Object price) {
    return 'CruizX Pro · $price/kuukausi · uusiutuu automaattisesti. Peruuta milloin tahansa Asetuksista vähintään 24 tuntia ennen uusimista. Veloitetaan Apple ID -tililtäsi.';
  }

  @override
  String paywallDisclosureAndroid(Object price) {
    return 'CruizX Pro · $price/kuukausi · uusiutuu automaattisesti. Hallitaan ja laskutetaan Stripen kautta. Peruuta milloin tahansa osoitteessa cruizx.com tai ota yhteyttä tukeen.';
  }

  @override
  String get paywallPriceOneTime => '79 kr';

  @override
  String paywallDisclosureOneTime(Object price) {
    return 'CruizX Pro · $price · kertaosto. Veloitetaan kerran Apple ID -tililtäsi. Ei tilausta eikä uusimista.';
  }

  @override
  String get paywallFreeLabel => 'Free';

  @override
  String get paywallProLabel => 'Pro';

  @override
  String get paywallStartTrialButton => 'Aloita 7 päivän ilmainen kokeilu';

  @override
  String paywallTrialNote(Object price) {
    return '7 päivää ilmaiseksi, sitten $price kertamaksuna.';
  }

  @override
  String get paywallFeatureRoutes => 'Reittejä päivässä';

  @override
  String get paywallFreeRouteLimit => '4 reittiä';

  @override
  String get paywallProRouteLimit => 'Rajaton';

  @override
  String get paywallFeatureConvoy => 'Saattue';

  @override
  String get paywallFreeConvoyLimit => '1 aktiivinen, 2 jäsentä';

  @override
  String get paywallProConvoyLimit => 'Rajaton';

  @override
  String get paywallFeatureAds => 'Mainokset';

  @override
  String get paywallFreeAds => 'Näytetään';

  @override
  String get paywallProAds => 'Ei mainoksia';

  @override
  String get paywallRouteLimitTitle => 'Päivittäinen reittirajaus saavutettu';

  @override
  String get paywallRouteLimitBody => 'Ilmaiskäyttäjät voivat laskea 4 reittiä päivässä. Päivitä Prohon rajattomaan navigointiin.';

  @override
  String get paywallConvoyLimitTitle => 'Saattueraja saavutettu';

  @override
  String get paywallConvoyLimitBody => 'Ilmaiskäyttäjät voivat olla vain 1 saattueessa kerrallaan.';

  @override
  String get paywallMemberLimitTitle => 'Saattue on täynnä';

  @override
  String get paywallMemberLimitBody => 'Ilmaiskäyttäjät voivat liittyä vain saattueisiin, joissa on alle 2 jäsentä. Päivitä Prohon rajattomaan pääsyyn.';

  @override
  String get paywallPurchaseSuccess => 'Olet nyt Pro-käyttäjä!';

  @override
  String get paywallPurchaseFailed => 'Ostoa ei voitu suorittaa. Tarkista App Store -tilisi ja yritä uudelleen.';

  @override
  String get paywallRestoreSuccess => 'Osto palautettu!';

  @override
  String get paywallLoginRequiredTitle => 'Kirjautuminen vaaditaan';

  @override
  String get paywallLoginRequiredBody => 'Tarvitset tilin ostaaksesi CruizX Pron. Luo ilmainen tili sovelluksessa jatkaaksesi.';

  @override
  String get paywallLoginRequiredAction => 'OK';

  @override
  String get paywallRestoreNotFound => 'Aiempaa ostoa ei löytynyt.';

  @override
  String get profileFreePlan => 'Ilmaisversio';

  @override
  String get profileProPlan => 'Pro-versio';

  @override
  String get profileUpgradeToPro => 'Päivitä Prohon';

  @override
  String profileRoutesUsed(Object count, Object max) {
    return 'Reitit tänään: $count / $max';
  }

  @override
  String get profileChangePhoto => 'Vaihda profiilikuva';

  @override
  String get profileTakePhoto => 'Ota kuva';

  @override
  String get profileChooseFromGallery => 'Valitse galleriasta';

  @override
  String get profilePhotoUploadFailed => 'Kuvan lataus epäonnistui';

  @override
  String get parentModeTitle => 'Vanhempi-tila';

  @override
  String get parentModeDescription => 'Anna vanhemman seurata ajoasi reaaliajassa.';

  @override
  String get parentModeLoginRequired => 'Sinun on oltava kirjautuneena käyttääksesi vanhempi-tilaa.';

  @override
  String get parentModeEnable => 'Ota vanhempi-tila käyttöön';

  @override
  String get parentModeEnabledSubtitle => 'Vanhemmat voivat seurata ajoasi';

  @override
  String get parentModeDisabledSubtitle => 'Ei jakamista aktiivisena';

  @override
  String get parentModeInviteCode => 'Kutsukoodi';

  @override
  String get parentModeInviteCodeSubtitle => 'Jaa tämä koodi vanhemmallesi yhdistääksesi heidän tilinsä.';

  @override
  String get parentModeCopyCode => 'Kopioi';

  @override
  String get parentModeShareCode => 'Jaa';

  @override
  String get parentModeCodeCopied => 'Koodi kopioitu!';

  @override
  String get parentModeShareSubject => 'CruizX Vanhempikoodi';

  @override
  String parentModeShareMessage(Object code) {
    return 'Hei! Käytä tätä koodia seurataksesi ajoani CruizX:ssä: $code';
  }

  @override
  String get parentModeLinkedParents => 'Yhdistetyt vanhemmat';

  @override
  String get parentModeNoParentsLinked => 'Ei yhdistettyjä vanhempia vielä. Jaa koodisi!';

  @override
  String get parentModeUnlinkTitle => 'Poista vanhempi?';

  @override
  String parentModeUnlinkMessage(Object name) {
    return 'Haluatko poistaa käyttäjän $name vanhempana? He eivät voi enää seurata ajoasi.';
  }

  @override
  String get parentModeUnlink => 'Poista';

  @override
  String get parentModeShareSettings => 'Mitä jaetaan';

  @override
  String get parentModeShareLocation => 'Jaa sijainti';

  @override
  String get parentModeShareLocationSubtitle => 'Näytä sijaintisi kartalla';

  @override
  String get parentModeShareSpeed => 'Jaa nopeus';

  @override
  String get parentModeShareSpeedSubtitle => 'Näytä nykyinen nopeutesi';

  @override
  String get parentModeAlertSettings => 'Ilmoitukset vanhemmille';

  @override
  String get parentModeSpeedAlert => 'Nopeushälytys';

  @override
  String parentModeSpeedAlertSubtitle(Object limit) {
    return 'Ilmoita kun nopeus ylittää $limit km/h';
  }

  @override
  String get parentModeSpeedLimit => 'Raja';

  @override
  String get parentModeNightAlert => 'Yöajohälytys';

  @override
  String parentModeNightAlertSubtitle(Object start, Object end) {
    return 'Ilmoita ajosta klo $start–$end välillä';
  }

  @override
  String get cancel => 'Peruuta';

  @override
  String get login => 'Kirjaudu sisään';

  @override
  String get parentDashboardTitle => 'Vanhemman hallintapaneeli';

  @override
  String get parentDashboardMapTab => 'Kartta';

  @override
  String get parentDashboardAlertsTab => 'Hälytykset';

  @override
  String get parentDashboardAddChild => 'Lisää lapsi';

  @override
  String get parentDashboardOnline => 'Online';

  @override
  String get parentDashboardOffline => 'Offline';

  @override
  String get parentDashboardNoAlerts => 'Ei hälytyksiä viimeisten 24 tunnin aikana';

  @override
  String get parentDashboardNoChildren => 'Ei yhdistettyjä lapsia vielä';

  @override
  String get parentDashboardNoChildrenHint => 'Lisää lapsi syöttämällä heidän kutsukoodinsa CruizX Vanhempi-tilasta.';

  @override
  String get parentDashboardEnterCode => 'Syötä kutsukoodi';

  @override
  String get parentDashboardEnterCodeHint => 'Pyydä lastasi jakamaan 6-merkkinen kutsukoodinsa Vanhempi-tilan asetuksista.';

  @override
  String get parentDashboardLink => 'Yhdistä';

  @override
  String get parentDashboardLinkSuccess => 'Yhdistäminen onnistui!';

  @override
  String get parentDashboardLinkFailed => 'Lasta ei löytynyt tällä koodilla. Tarkista koodi ja yritä uudelleen.';

  @override
  String get parentDashboardLinkSelf => 'Et voi yhdistää omaan tiliisi. Pyydä lastasi jakamaan koodinsa omalta tililtään.';

  @override
  String get parentDashboardSpeedingAlert => 'Nopeushälytys';

  @override
  String parentDashboardSpeedingDetail(Object name, Object speed, Object limit) {
    return '$name ajoi nopeudella $speed km/h (raja: $limit km/h)';
  }

  @override
  String get parentDashboardNightAlert => 'Yöajo';

  @override
  String parentDashboardNightDetail(Object name) {
    return '$name ajaa yöllä';
  }

  @override
  String get parentDashboardViewChild => 'Näytä vanhempana';

  @override
  String get settingsVoiceNavigation => 'Ääninavigointi';

  @override
  String get settingsVoiceNavigationSubtitle => 'Lue käännösohjeet ääneen';

  @override
  String get voiceTurnLeft => 'Käänny vasemmalle';

  @override
  String get voiceTurnRight => 'Käänny oikealle';

  @override
  String get voiceTurnSharpLeft => 'Käänny jyrkästi vasemmalle';

  @override
  String get voiceTurnSharpRight => 'Käänny jyrkästi oikealle';

  @override
  String get voiceTurnSlightLeft => 'Käänny loivasti vasemmalle';

  @override
  String get voiceTurnSlightRight => 'Käänny loivasti oikealle';

  @override
  String get voiceContinue => 'Jatka suoraan';

  @override
  String get voiceRoundabout => 'Aja liikenneympyrään';

  @override
  String get voiceDestination => 'Olet saapunut määränpäähäsi';

  @override
  String voiceInMeters(Object meters) {
    return '$meters metrin päässä';
  }

  @override
  String voiceInKm(Object km) {
    return '$km kilometrin päässä';
  }

  @override
  String get mfaSetupTitle => 'Ota kaksivaiheinen tunnistautuminen käyttöön';

  @override
  String get mfaSetupSubtitle => 'Skannaa QR-koodi tunnistautumissovelluksella, kuten Google Authenticator tai Authy';

  @override
  String get mfaScanQr => 'Skannaa yllä oleva koodi ja syötä 6-numeroinen koodi alle';

  @override
  String get mfaVerifyButton => 'Vahvista';

  @override
  String get mfaVerifyTitle => 'Kaksivaiheinen tunnistautuminen';

  @override
  String get mfaVerifySubtitle => 'Syötä 6-numeroinen koodi tunnistautumissovelluksestasi';

  @override
  String get mfaInvalidCode => 'Virheellinen koodi, yritä uudelleen';

  @override
  String get mfaCancel => 'Peruuta ja kirjaudu ulos';

  @override
  String get mfaProfileTitle => 'Kaksivaiheinen tunnistautuminen';

  @override
  String get mfaStatusOn => 'Käytössä — tilisi on suojattu';

  @override
  String get mfaStatusOff => 'Pois käytöstä';

  @override
  String get mfaTurnOn => 'Ota käyttöön';

  @override
  String get mfaTurnOff => 'Poista käytöstä';

  @override
  String get mfaDisableTitle => 'Poista 2FA käytöstä?';

  @override
  String get mfaDisableBody => 'Tilisi on vähemmän turvassa ilman kaksivaiheista tunnistautumista.';

  @override
  String get mfaDisableConfirm => 'Poista käytöstä';

  @override
  String get mfaShowManualKey => 'Etkö voi skannata? Näytä avain manuaalisesti';

  @override
  String get mfaHideManualKey => 'Piilota manuaalinen avain';

  @override
  String get mfaKeyCopied => 'Avain kopioitu';

  @override
  String get mfaRecommendTitle => 'Suojaa tilisi';

  @override
  String get mfaRecommendBody => 'Suosittelemme kaksivaiheisen tunnistautumisen käyttöönottoa tilisi suojaamiseksi. Voit käyttää tunnistautumissovellusta, kuten Google Authenticator tai Authy.';

  @override
  String get mfaRecommendSetup => 'Ota käyttöön nyt';

  @override
  String get mfaRecommendLater => 'Myöhemmin';

  @override
  String get favHome => 'Koti';

  @override
  String get favSchool => 'Koulu';

  @override
  String get favWork => 'Työ';

  @override
  String get favAddTitle => 'Tallenna paikka';

  @override
  String get favLabelHint => 'Nimi (esim. Kaveri)';

  @override
  String get favSaved => 'Paikka tallennettu';

  @override
  String get favDeleted => 'Paikka poistettu';

  @override
  String favDeleteConfirm(Object name) {
    return 'Poista $name?';
  }

  @override
  String favSetAs(Object type) {
    return 'Tallenna kohteeksi $type';
  }

  @override
  String get favCustom => 'Muu suosikki';

  @override
  String get ttsVoiceHint => 'Vinkki: Lataa parempia ääniä kohdasta Asetukset → Esteettömyys → Puhuttu sisältö → Äänet';

  @override
  String get ttsVoiceHintDismiss => 'OK';

  @override
  String get settingsVectorMap => 'Vektorikartta';

  @override
  String get settingsVectorMapOn => 'Tarkka renderöinti kaikilla zoomitasoilla, pehmeä zoom';

  @override
  String get settingsVectorMapOff => 'Vakio — nopea ja offline-välimuistissa';

  @override
  String get publicGatheringStartTime => 'Aloitusaika';

  @override
  String get publicGatheringEndTime => 'Päättymisaika';

  @override
  String get publicGatheringScheduleInvalid => 'Päättymisajan on oltava aloitusajan jälkeen.';

  @override
  String get publicGatheringEndAction => 'Päätä tapaaminen';

  @override
  String get publicGatheringDeleteAction => 'Poista tapaaminen';

  @override
  String get publicGatheringEndConfirm => 'Päätetäänkö tapaaminen nyt? Osallistujat eivät enää löydä sitä.';

  @override
  String get publicGatheringDeleteConfirm => 'Poistetaanko tapaaminen pysyvästi? Tätä ei voi perua.';

  @override
  String get publicGatheringReportAction => 'Ilmoita tapaamisesta';

  @override
  String get publicGatheringBlockAction => 'Estä tapaaminen';

  @override
  String get publicGatheringReportParticipant => 'Ilmoita osallistujasta';

  @override
  String get publicGatheringBlockParticipant => 'Estä osallistuja';

  @override
  String get publicGatheringReportReason => 'Mitä haluat ilmoittaa?';

  @override
  String get publicGatheringReportSent => 'Ilmoitus on lähetetty.';

  @override
  String get publicGatheringBlocked => 'Estettyä sisältöä ei enää näytetä.';

  @override
  String get reportReasonInappropriate => 'Sopimaton sisältö';

  @override
  String get reportReasonHarassment => 'Häirintä';

  @override
  String get reportReasonDangerous => 'Vaarallinen toiminta';

  @override
  String get reportReasonSpam => 'Roskaposti tai harhaanjohtava';

  @override
  String get reportReasonOther => 'Muu';

  @override
  String get publicGatheringNearbyNotifications => 'Ilmoitukset lähellä olevista tapaamisista';

  @override
  String get publicGatheringNearbyNotificationsSubtitle => 'Ilmoita kerran, kun 25 km:n sisällä oleva julkinen tapaaminen alkaa 24 tunnin kuluessa.';

  @override
  String get publicGatheringUpcoming => 'Tulossa';

  @override
  String get publicGatheringStarted => 'Käynnissä';
}
