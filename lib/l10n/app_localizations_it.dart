// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'CruizX';

  @override
  String get navMap => 'Mappa';

  @override
  String get navAlerts => 'Avvisi';

  @override
  String get navConvoy => 'Convoglio';

  @override
  String get navProfile => 'Profilo';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get splashPreparingStartup => 'Preparazione dell\'avvio...';

  @override
  String get splashLoadingCoreModules => 'Caricamento dei moduli principali...';

  @override
  String get splashInitializingAccountSession => 'Inizializzazione della sessione dell\'account in corso...';

  @override
  String get splashLoadingPreferences => 'Caricamento preferenze...';

  @override
  String get splashFinalizingStartup => 'Finalizzazione dell\'avvio...';

  @override
  String get splashReady => 'Pronto';

  @override
  String get splashVersionLine => 'v1.1.7 | CruizX di KimTechTool';

  @override
  String get a11yCenterOnLocation => 'Centra la mappa sulla mia posizione';

  @override
  String get a11yStopFollowingLocation => 'Smetti di seguire la mia posizione';

  @override
  String get a11ySwitchTo2d => 'Passa alla mappa 2D';

  @override
  String get a11ySwitchTo3d => 'Passa alla mappa 3D';

  @override
  String get a11yUseDarkMap => 'Usa la mappa scura';

  @override
  String get a11yUseLightMap => 'Usa la mappa chiara';

  @override
  String get a11yEnableVoiceNavigation => 'Attiva la navigazione vocale';

  @override
  String get a11yDisableVoiceNavigation => 'Disattiva la navigazione vocale';

  @override
  String get a11yDismissAlert => 'Chiudi l’avviso';

  @override
  String get a11yClearSearch => 'Cancella la ricerca';

  @override
  String get a11yOpenSearch => 'Apri la ricerca indirizzo';

  @override
  String get a11yAddFavorite => 'Aggiungi luogo preferito';

  @override
  String get a11yConfirmAlert => 'Conferma l’avviso';

  @override
  String get alertsTitle => 'Avvisi della comunità';

  @override
  String get alertsSubtitle => 'Segnala e visualizza i pericoli stradali, i controlli e le condizioni stradali.';

  @override
  String get convoyRequiresSignInTitle => 'Il convoglio richiede l\'accesso';

  @override
  String get convoyRequiresSignInSubtitle => 'Accedi o crea un account qui per creare gruppi di convogli e vedere posizioni in tempo reale.';

  @override
  String get signIn => 'Accedi';

  @override
  String get signUp => 'Creare un account';

  @override
  String get signOut => 'Esci';

  @override
  String get signInEmailDialogTitle => 'Accedi con l\'e-mail OTP';

  @override
  String get signUpEmailDialogTitle => 'Crea un account con e-mail OTP';

  @override
  String get signInEmailFieldLabel => 'E-mail';

  @override
  String get signInEmailHint => 'nome@esempio.com';

  @override
  String get signInSendOtp => 'Invia codice';

  @override
  String get signUpSendOtp => 'Invia codice account';

  @override
  String get signInOtpFieldLabel => 'Codice OTP';

  @override
  String get signInOtpHint => 'Codice a 6 cifre';

  @override
  String get signInVerifyOtp => 'Verifica il codice';

  @override
  String get signInOtpSent => 'Codice OTP inviato alla tua email.';

  @override
  String get signUpOtpSent => 'Codice di creazione dell\'account inviato alla tua email.';

  @override
  String get signInOtpInvalid => 'Impossibile verificare l\'OTP. Controlla il tuo codice e riprova.';

  @override
  String get signUpNoAccountAction => 'Non hai un account? Creane uno';

  @override
  String get signUpHaveAccountAction => 'Hai già un account? Accedi';

  @override
  String get authGenericError => 'Qualcosa è andato storto. Per favore riprova.';

  @override
  String get authWelcomeBack => 'Bentornati su CruizX';

  @override
  String get authRegisterSubtitle => 'Unisciti alla comunità CruizX';

  @override
  String get authEmailLabel => 'Indirizzo e-mail';

  @override
  String get authEmailRequired => 'Inserisci il tuo indirizzo email';

  @override
  String get authEmailInvalid => 'E-mail non valida';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordRequired => 'Inserisci la tua password';

  @override
  String get authPasswordMinLength => 'Almeno 6 caratteri';

  @override
  String get authConfirmPasswordLabel => 'Conferma password';

  @override
  String get authConfirmPasswordRequired => 'Conferma la tua password';

  @override
  String get authPasswordsDoNotMatch => 'Le password non corrispondono.';

  @override
  String get authDisplayNameLabel => 'Nome da visualizzare';

  @override
  String get authDisplayNameRequired => 'Inserisci il tuo nome';

  @override
  String get authNoAccountPrompt => 'Non hai un account?';

  @override
  String get authAlreadyHaveAccountPrompt => 'Hai già un account?';

  @override
  String get authCancel => 'Cancellare';

  @override
  String get authForgotPasswordLink => 'Ha dimenticato la password?';

  @override
  String get authForgotPasswordTitle => 'Reimposta la password';

  @override
  String get authForgotPasswordDescription => 'Inserisci il tuo indirizzo email e ti invieremo un collegamento per reimpostare la password.';

  @override
  String get authForgotPasswordButton => 'Invia collegamento di reimpostazione';

  @override
  String get authForgotPasswordSuccess => 'Se l\'account esiste, abbiamo inviato un collegamento di reimpostazione alla tua email.';

  @override
  String get authResetPasswordTitle => 'Nuova password';

  @override
  String get authResetPasswordDescription => 'Inserisci la tua nuova password qui sotto.';

  @override
  String get authNewPasswordLabel => 'Nuova password';

  @override
  String get authResetPasswordButton => 'Salva password';

  @override
  String get authResetPasswordSuccess => 'La tua password è stata modificata.';

  @override
  String get authErrorAllFieldsRequired => 'Tutti i campi sono obbligatori.';

  @override
  String get authErrorPasswordTooShort => 'La password deve contenere almeno 6 caratteri.';

  @override
  String get authErrorConfirmEmail => 'Controlla la tua email per confermare il tuo account, quindi accedi.';

  @override
  String get authEmailConfirmedTitle => 'E-mail confermata';

  @override
  String get authEmailConfirmedBody => 'Il tuo indirizzo e-mail è stato confermato. Ora hai effettuato l\'accesso.';

  @override
  String get authErrorEmailAndPasswordRequired => 'Inserisci la tua email e la password.';

  @override
  String get authErrorInvalidCredentials => 'E-mail o password errati.';

  @override
  String get authErrorEmailAlreadyInUse => 'Esiste già un account con quell\'e-mail.';

  @override
  String get authErrorInvalidEmail => 'L’indirizzo e-mail non è valido. Controllalo e riprova.';

  @override
  String get authErrorRateLimited => 'Troppi tentativi in poco tempo. Attendi un momento e riprova.';

  @override
  String get authErrorSignUpDisabled => 'Al momento non è possibile creare nuovi account. Contatta l’assistenza CruizX.';

  @override
  String get authErrorEmailDeliveryFailed => 'Non è stato possibile inviare l’e-mail di conferma. Riprova tra poco.';

  @override
  String get authErrorNetworkUnavailable => 'Impossibile connettersi al servizio account. Controlla la connessione Internet e riprova.';

  @override
  String get convoyRealtimeBackendMissing => 'Il convoglio in tempo reale non è ancora configurato. Aggiungi la configurazione del backend per condividere posizioni live tra gli utenti.';

  @override
  String get convoyModeTitle => 'Modalità convoglio';

  @override
  String get convoyModeSubtitle => 'Crea guida di gruppo con una destinazione condivisa e posizioni in tempo reale.';

  @override
  String get convoyCreateButton => 'Crea convoglio';

  @override
  String get publicGatheringsTitle => 'Incontri pubblici';

  @override
  String get publicGatheringsSubtitle => 'Trova un punto di incontro, partecipa pubblicamente e scegli se mostrare la tua posizione dal vivo.';

  @override
  String get publicGatheringsMineTab => 'Mio';

  @override
  String get publicGatheringsPublicTab => 'Pubblico';

  @override
  String get publicGatheringsEmpty => 'Non ci sono incontri pubblici attivi al momento.';

  @override
  String get publicGatheringCreateButton => 'Crea un incontro pubblico';

  @override
  String get publicGatheringCreateTitle => 'Nuovo incontro pubblico';

  @override
  String get publicGatheringPlaceHint => 'Luogo d\'incontro, ad es. la piazza della città';

  @override
  String get publicGatheringLocationExplanation => 'L\'incontro viene posizionato nella tua posizione attuale e rimane attivo per 6 ore. La posizione dal vivo è facoltativa per ogni partecipante.';

  @override
  String get publicGatheringLocationRequired => 'Per impostare il luogo dell\'incontro è necessario l\'accesso alla posizione.';

  @override
  String get publicGatheringPublish => 'Pubblicare';

  @override
  String get publicGatheringStartSharing => 'Condividi la mia posizione dal vivo';

  @override
  String get publicGatheringStopSharing => 'Interrompi la condivisione della mia posizione live';

  @override
  String get convoyOpenButton => 'Aprire';

  @override
  String get convoyJoinButton => 'Giuntura';

  @override
  String get convoyLeaveButton => 'Partire';

  @override
  String get convoyJoinFirstHint => 'Unisciti prima al convoglio, quindi toccalo per aprire la chat e la mappa.';

  @override
  String get convoyJoinByCodeTitle => 'Unisciti al convoglio';

  @override
  String get convoyJoinByCodeHint => 'Inserisci il codice del convoglio che hai ricevuto';

  @override
  String get convoyJoinWithCodeButton => 'Giuntura';

  @override
  String get convoyJoinByCodeNotFound => 'Nessun convoglio trovato con quel codice.';

  @override
  String convoyJoinByCodeSuccess(String name) {
    return 'Ti sei iscritto a $name!';
  }

  @override
  String get convoyInviteButton => 'Invitare';

  @override
  String get convoyTabMap => 'Mappa';

  @override
  String get convoyTabChat => 'Chiacchierata';

  @override
  String get convoyMapHint => 'Tocca la mappa per posizionare un segnaposto condiviso.';

  @override
  String get convoyRecenterTooltip => 'Ricentra e segui la mia posizione';

  @override
  String get convoyPinDialogTitle => 'Aggiungi segnaposto sulla mappa';

  @override
  String get convoyPinLabel => 'Etichetta con perno';

  @override
  String get convoyPinHint => 'per esempio. Incontra qui';

  @override
  String get convoyPinAdd => 'Aggiungi puntina';

  @override
  String get convoyHazardPolice => 'Polizia Stradale ';

  @override
  String get convoyHazardRoadwork => 'Lavori stradali';

  @override
  String get convoyHazardAccident => 'Incidente';

  @override
  String get convoyHazardTrafficJam => 'Ingorgo stradale';

  @override
  String get convoyHazardSpeedCamera => 'Autovelox';

  @override
  String get convoyHazardCustom => 'Perno personalizzato';

  @override
  String get convoyPoiMeetup => 'Punto d\'incontro';

  @override
  String get convoyPoiMeetupSubtitle => 'Segna un luogo libero dove il convoglio dovrebbe radunarsi';

  @override
  String get convoyPoiParking => 'Parcheggio';

  @override
  String get convoyPoiFoodStop => 'Sosta gastronomica';

  @override
  String get convoyPoiCharging => 'In carica';

  @override
  String get routeStopFuel => 'Carburante';

  @override
  String get routeStopCafe => 'Caffetteria';

  @override
  String get routeStopGrocery => 'Drogheria';

  @override
  String get convoyPoiHangout => 'Luogo di ritrovo';

  @override
  String get convoyChatEmpty => 'Nessun messaggio ancora.';

  @override
  String get convoyChatPlaceholder => 'Scrivi un messaggio...';

  @override
  String get convoyChatSend => 'Inviare';

  @override
  String get convoyNameDialogTitle => 'Crea convoglio';

  @override
  String get convoyNameFieldLabel => 'Nome del convoglio';

  @override
  String get convoyNameHint => 'per esempio. Giro del venerdì sera';

  @override
  String get convoyCreateConfirm => 'Creare';

  @override
  String get convoyCreateCancel => 'Cancellare';

  @override
  String get convoyListEmpty => 'Ancora nessun convoglio. Crea il primo.';

  @override
  String get convoyListEmptyMine => 'Non ti sei ancora unito a nessun convoglio.';

  @override
  String get convoyFilterAll => 'Tutto';

  @override
  String get convoyFilterMine => 'Mio';

  @override
  String convoyMembers(Object count) {
    return '$count membri';
  }

  @override
  String get convoyMemberMe => 'Me';

  @override
  String convoyMemberStaleTime(Object mins) {
    return '$mins milioni fa';
  }

  @override
  String convoyCreatedBy(Object leader) {
    return 'Creato da $leader';
  }

  @override
  String get profileTitle => 'Profilo e statistiche';

  @override
  String get profileNotSignedIn => 'Non hai effettuato l\'accesso.';

  @override
  String get profileSignInInConvoyHint => 'L\'accesso è disponibile nella scheda Convoglio.';

  @override
  String profileSignedInAs(Object name) {
    return 'Accesso effettuato come: $name';
  }

  @override
  String get profileDefaultName => 'Driver CruizX';

  @override
  String get profileSignedIn => 'Effettuato l\'accesso';

  @override
  String get profileStatsTitle => 'Statistiche';

  @override
  String get profileStatsConvoys => 'Convogli guidati';

  @override
  String get profileStatsTotalDistance => 'Distanza totale';

  @override
  String get profileStatsSpeedViolations => 'Violazioni della velocità';

  @override
  String get profileVehicleTitle => 'Il mio veicolo';

  @override
  String get profileVehicleElectric => 'Veicolo elettrico';

  @override
  String get profileVehicleElectricSubtitle => 'Mostra le stazioni di ricarica sulla mappa';

  @override
  String get profileVehicleStuddedTires => 'Pneumatici chiodati';

  @override
  String get profileVehicleStuddedTiresSubtitle => 'Evita le strade in cui è vietato l\'uso dei pneumatici chiodati';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsLanguageLabel => 'Lingua';

  @override
  String get settingsLanguageSystem => 'Predefinito del sistema';

  @override
  String get settingsLanguageEnglish => 'Inglese';

  @override
  String get settingsLanguageSwedish => 'svedese';

  @override
  String get settingsLanguageFrench => 'francese';

  @override
  String get settingsLanguageNorwegian => 'norvegese';

  @override
  String get settingsLanguageDanish => 'danese';

  @override
  String get settingsLanguageFinnish => 'finlandese';

  @override
  String get settingsLanguageSpanish => 'spagnolo';

  @override
  String get settingsLanguageItalian => 'Italiano';

  @override
  String get settingsCountryLabel => 'Paese (regole del traffico)';

  @override
  String get settingsCountrySweden => '🇸🇪 Svezia';

  @override
  String get settingsCountryNorway => '🇳🇴 Norvegia';

  @override
  String get settingsCountryDenmark => '🇩🇰 Danimarca';

  @override
  String get settingsCountryFinland => '🇫🇮 Finlandia';

  @override
  String get settingsCountryFrance => '🇫🇷 Francia';

  @override
  String get settingsCountrySpain => '🇪🇸 Spagna';

  @override
  String get settingsCountryItaly => '🇮🇹 Italia';

  @override
  String get settingsCountryUnitedKingdom => '🇬🇧 Regno Unito';

  @override
  String get settingsCountryHint => 'I limiti di velocità e le regole stradali si adattano al paese selezionato.';

  @override
  String settingsLanguageCurrentlyUsing(Object mode) {
    return 'Attualmente in uso: $mode';
  }

  @override
  String get settingsVehicleTypeLabel => 'Tipo di veicolo';

  @override
  String get settingsVehicleAtractor => 'A-trattore';

  @override
  String get settingsVehicleLowVehicle => 'Veicolo basso';

  @override
  String get settingsVehicleMopedCar => 'Minicar';

  @override
  String get settingsVehicleMopedClassI => 'Ciclomotore classe I';

  @override
  String get settingsVehicleMopedClassII => 'Ciclomotore classe II (25 km/h)';

  @override
  String get settingsVehicleTractor => 'Trattore';

  @override
  String get settingsSpeedUnitKmh => 'km/h';

  @override
  String get settingsSpeedUnitMph => 'mph';

  @override
  String settingsMaxSpeedWithUnit(Object value, Object unit) {
    return 'Velocità massima: $value $unit';
  }

  @override
  String get settingsProCardTitle => 'CruizX Pro';

  @override
  String get settingsProStatusActive => 'Attivo';

  @override
  String get settingsProStatusInactive => 'Non attivo';

  @override
  String get settingsProDescriptionActive => 'Hai accesso a tutte le funzionalità Pro.';

  @override
  String get settingsProDescriptionInactive => 'Sblocca tutte le funzionalità con CruizX Pro.';

  @override
  String get settingsProFeatureRoutes => 'Percorsi illimitati';

  @override
  String get settingsProFeatureConvoy => 'Membri del convoglio illimitati';

  @override
  String get settingsProFeatureAds => 'Nessuna pubblicità';

  @override
  String get settingsProFeatureSupport => 'Supporto prioritario';

  @override
  String get settingsProSubscriptionNote => 'Abbonamento: CruizX Pro mensile (1 mese). Il pagamento viene addebitato sul tuo ID Apple e si rinnova automaticamente a meno che non venga annullato almeno 24 ore prima della fine del periodo corrente.';

  @override
  String settingsProPricePerMonth(Object price) {
    return '$price /mese';
  }

  @override
  String settingsProPriceOneTime(Object price) {
    return '$price';
  }

  @override
  String get settingsProOneTimeNote => 'Acquisto una tantum: CruizX Pro (a vita). Il pagamento viene addebitato una volta tramite l’app store. Nessun abbonamento e nessun rinnovo automatico.';

  @override
  String get settingsPrivacyPolicyLabel => 'politica sulla riservatezza';

  @override
  String get settingsTermsOfUseLabel => 'Condizioni d\'uso (EULA)';

  @override
  String get settingsSupportLabel => 'Supporto';

  @override
  String get supportChatTitle => 'Chat dal vivo con l’assistenza';

  @override
  String get supportChatReplyTime => 'Rispondiamo entro 24 ore';

  @override
  String get supportChatWelcome => 'Ciao! Come possiamo aiutarti con CruizX? Scrivi qui il tuo messaggio e ti risponderemo il prima possibile.';

  @override
  String get supportChatGuestNotice => 'Stai chattando come ospite. La conversazione viene salvata in modo privato su questo dispositivo.';

  @override
  String get supportChatLoginRequired => 'Accedi per avviare una chat privata con l’assistenza e vedere i messaggi precedenti.';

  @override
  String get supportChatLoginAction => 'Accedi';

  @override
  String get supportChatMessageHint => 'Scrivi un messaggio…';

  @override
  String get supportChatSend => 'Invia messaggio';

  @override
  String get supportChatSendFailed => 'Impossibile inviare il messaggio. Riprova.';

  @override
  String get supportChatUnavailable => 'La chat di assistenza non è disponibile al momento. Riprova più tardi.';

  @override
  String get supportChatTeam => 'Assistenza CruizX';

  @override
  String get supportChatYou => 'Tu';

  @override
  String get settingsLinkOpenFailed => 'Impossibile aprire il collegamento in questo momento.';

  @override
  String get settingsRestorePurchaseFailed => 'Impossibile ripristinare l\'acquisto.';

  @override
  String get settingsMapMarkerLabel => 'Indicatore della mappa';

  @override
  String get settingsMapMarkerCategoryClassic => 'Classico';

  @override
  String get settingsMapMarkerCategoryMicrocar => 'Auto ciclomotore';

  @override
  String get settingsMapMarkerCategoryEpa => 'EPA';

  @override
  String get settingsMapMarkerCategoryLigier => 'Ligier';

  @override
  String get settingsMapMarkerCategoryAixam => 'Aixam';

  @override
  String get settingsMapMarkerCategoryPickup => 'Pickup';

  @override
  String get settingsMapMarkerCategoryAtractor => 'A-trattore';

  @override
  String get settingsMapMarkerCategoryTractor => 'Trattore';

  @override
  String get settingsMapMarkerArrow => 'Freccia';

  @override
  String get settingsMapMarkerCompass => 'Bussola';

  @override
  String get settingsMapMarkerTriangle => 'Triangolo';

  @override
  String get settingsMapMarkerDot => 'Punto';

  @override
  String get settingsMapMarkerEpa => 'EPA';

  @override
  String get settingsMapMarkerMicrocar => 'Minicar';

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
  String get settingsMapMarkerMopeds => 'Ciclomotori';

  @override
  String get settingsMapMarkerScooter => 'Scooter';

  @override
  String get settingsMapMarkerCrossMoped => 'Ciclomotore da cross';

  @override
  String get settingsMapMarkerTractor => 'Trattore';

  @override
  String get settingsColorRed => 'Rosso';

  @override
  String get settingsColorBlue => 'Blu';

  @override
  String get settingsColorBlack => 'Nero';

  @override
  String get settingsColorWhite => 'Bianco';

  @override
  String get settingsColorGold => 'Oro';

  @override
  String get settingsColorSilver => 'Argento';

  @override
  String get settingsColorGreen => 'Verde';

  @override
  String get settingsColorGraphite => 'Grafite';

  @override
  String get settingsColorYellow => 'Giallo';

  @override
  String get settingsColorOrange => 'Arancia';

  @override
  String get settingsColorPink => 'Rosa';

  @override
  String get navigationTitle => 'Navigazione passo passo';

  @override
  String get navigationSubtitle => 'Indicazioni stradali, svolta successiva ed ETA ottimizzati per i veicoli lenti.';

  @override
  String get mapStartingGps => 'Avvio del GPS...';

  @override
  String get mapTapToSelectDestination => 'Tocca la mappa per selezionare una destinazione';

  @override
  String get mapAddressFieldHint => 'Indirizzo di ricerca (ad esempio Main St 10, Stoccolma)';

  @override
  String get mapSearchingAddress => 'Ricerca indirizzo...';

  @override
  String get mapAddressNotFound => 'Nessun indirizzo trovato. Riprova.';

  @override
  String get mapAddressLookupFailed => 'Impossibile cercare l\'indirizzo in questo momento';

  @override
  String get mapLocationServicesDisabled => 'I servizi di localizzazione sono disabilitati';

  @override
  String get mapLocationPermissionMissing => 'Manca l\'autorizzazione alla posizione';

  @override
  String get mapGpsActive => 'GPS attivo';

  @override
  String get mapGpsUnavailable => 'Il GPS non è disponibile in questo ambiente';

  @override
  String get mapWaitingForGps => 'In attesa della posizione GPS prima del calcolo del percorso';

  @override
  String get mapCalculatingRoute => 'Calcolo del percorso...';

  @override
  String mapRouteReady(Object distance, Object minutes) {
    return 'Percorso pronto: $distance km • $minutes min';
  }

  @override
  String get mapRouteFailed => 'Impossibile creare il percorso in questo momento';

  @override
  String get mapRemaining => 'Sinistra';

  @override
  String get mapRouteNoRouteFound => 'Nessun percorso trovato tra i punti selezionati';

  @override
  String get mapRouteProviderUnavailable => 'Il servizio di routing non è al momento disponibile';

  @override
  String get mapRouteMissingApiKey => 'Il routing non è configurato sul backend (chiave API mancante)';

  @override
  String get mapRouteInvalidGeometry => 'I dati del percorso dal server non sono validi';

  @override
  String get mapRouteUnknownProvider => 'Il provider di routing non è configurato correttamente';

  @override
  String get mapRouteTooFastForVehicle => 'Itinerario rifiutato: la velocità media stimata è troppo alta per questo tipo di veicolo.';

  @override
  String get mapRouteNotAllowedForVehicle => 'Nessun percorso conforme alla legge trovato per questo tipo di veicolo.';

  @override
  String get routeStopSheetSubtitle => 'Fermate più vicine lungo il percorso attuale';

  @override
  String get routeStopNearbySubtitle => 'Opzioni più vicine intorno a te';

  @override
  String get routeStopEmpty => 'Non ci sono fermate valide vicino al percorso in questo momento.';

  @override
  String get routeStopNearbyEmpty => 'Non ci sono buone opzioni vicino a te in questo momento.';

  @override
  String get searchSaved => 'Salvato';

  @override
  String get searchRecent => 'Recente';

  @override
  String get searchNew => 'Nuovo';

  @override
  String routeStopFromRoute(Object distance) {
    return '$distance dal percorso';
  }

  @override
  String routeStopAway(Object distance) {
    return '$distance lontano';
  }

  @override
  String get routeBlockedTitle => 'Itinerario non disponibile';

  @override
  String routeBlockedBody(Object vehicleType) {
    return 'Non è stato trovato alcun percorso legale verso questa destinazione per il tuo $vehicleType. La destinazione può trovarsi su o essere raggiungibile solo tramite strade non consentite per questo tipo di veicolo (ad esempio autostrade).';
  }

  @override
  String get routeBlockedOk => 'OK';

  @override
  String get routeBlockedTryOther => 'Prova una destinazione diversa';

  @override
  String get routeFallbackTitle => 'Trovato percorso non verificato';

  @override
  String routeFallbackBody(Object vehicleType) {
    return 'Abbiamo trovato un percorso possibile, ma non è stato possibile verificarlo completamente per il tuo $vehicleType. Potrebbe includere strade che necessitano di controllo. Seguire sempre la segnaletica e le regole locali.';
  }

  @override
  String get routeFallbackCancel => 'Cancellare';

  @override
  String get routeFallbackUse => 'Mostra comunque';

  @override
  String get routeFallbackActive => 'Percorso non verificato: seguire sempre le indicazioni';

  @override
  String get routeOptionsTitle => 'Scegli percorso';

  @override
  String get routeOptionRecommended => 'Raccomandato';

  @override
  String get routeOptionRecommendedSubtitle => 'Verificato dalle regole CruizX per il veicolo selezionato.';

  @override
  String get routeOptionAlternative => 'Percorso alternativo';

  @override
  String get routeOptionAlternativeSubtitle => 'Percorso legale: strade diverse o leggermente più lunghe.';

  @override
  String get routeOptionUnverified => 'Percorso alternativo non verificato';

  @override
  String routeOptionUnverifiedSubtitle(Object vehicleType) {
    return 'Impossibile verificare completamente il tuo $vehicleType. Controllare la segnaletica prima di mettersi alla guida.';
  }

  @override
  String get routeOptionChoose => 'Scegliere';

  @override
  String routeOptionMetrics(Object km, Object minutes) {
    return '$km km · $minutes min';
  }

  @override
  String get routeOptionWarningFooter => 'CruizX non approva mai automaticamente le strade soggette a restrizioni. Seguire sempre la segnaletica e le regole locali.';

  @override
  String get mapModeLabel2d => '2D';

  @override
  String get mapModeLabel3d => '3D';

  @override
  String mapManeuverInDistance(Object distance) {
    return 'In $distance';
  }

  @override
  String mapManeuverTowardRoad(Object road) {
    return 'Verso $road';
  }

  @override
  String get mapSimulateButton => 'Simulare';

  @override
  String get speedometerLiveSpeed => 'Velocità dal vivo';

  @override
  String speedometerMaxSpeedWithUnit(Object value, Object unit) {
    return 'Velocità massima: $value $unit';
  }

  @override
  String get speedometerSlowDown => 'Rallentare.';

  @override
  String get reportAlertTitle => 'Segnala avviso';

  @override
  String get reportAlertDescHint => 'Descrizione (facoltativa)';

  @override
  String get reportAlertSubmit => 'Invia avviso';

  @override
  String reportAlertNearby(Object type, Object distance) {
    return '$type · $distance m avanti';
  }

  @override
  String get alertTypeRoadClosure => 'Chiusura stradale';

  @override
  String get alertTypePolice => 'Polizia Stradale ';

  @override
  String get alertTypeRoadwork => 'Lavori stradali';

  @override
  String get alertTypeAccident => 'Incidente';

  @override
  String get alertTypeTrafficJam => 'Ingorgo stradale';

  @override
  String get alertTypeSpeedCamera => 'Autovelox';

  @override
  String get alertTypeHazard => 'Pericolo';

  @override
  String get alertTypeNarrowRoad => 'Strada stretta';

  @override
  String get alertTypeSteepHill => 'Collina ripida';

  @override
  String get alertTypeSpeedBump => 'Urto ad alta velocità';

  @override
  String get alertTypeMeetup => 'Punto d\'incontro';

  @override
  String get alertTypeParking => 'Parcheggio';

  @override
  String get alertTypeFoodStop => 'Sosta gastronomica';

  @override
  String get alertTypeCharging => 'In carica';

  @override
  String get alertTypeHangout => 'Luogo di ritrovo';

  @override
  String get alertGpsUnavailable => 'GPS non ancora disponibile';

  @override
  String get alertMustBeLoggedIn => 'Devi essere registrato per segnalare';

  @override
  String get alertsScreenSubtitle => 'Informazioni in tempo reale dagli autisti Trafikverket e CruizX entro ~50 km. Tocca il pollice per confermare gli avvisi della community.';

  @override
  String get alertReportButton => 'Rapporto';

  @override
  String get alertTimeJustNow => 'Proprio adesso';

  @override
  String alertTimeMinutes(Object n) {
    return '$n minuti fa';
  }

  @override
  String alertTimeHours(Object n) {
    return '$n ore fa';
  }

  @override
  String get alertsEmptyTitle => 'Nessun avviso attivo nelle vicinanze';

  @override
  String get alertsEmptySubtitle => 'Vedi qualcosa sulla strada? Segnalalo!';

  @override
  String get alertReportQuestion => 'Cosa vedi sulla strada?';

  @override
  String get alertReportDescHint2 => 'Descrizione facoltativa... (ad esempio \"ramo grande\")';

  @override
  String get alertReportedSuccess => 'Avviso segnalato! Grazie 🙏';

  @override
  String get alertReportFailed => 'Impossibile segnalare l\'avviso in questo momento.';

  @override
  String get adBannerLoading => 'Caricamento annuncio...';

  @override
  String get adBannerWaitingRetry => 'L\'annuncio è in attesa della rete… (tocca per riprovare)';

  @override
  String get mapStartNavigation => 'Avvia la navigazione';

  @override
  String get mapEndNavigation => 'Termina la navigazione';

  @override
  String get convoyShowAll => 'Mostra tutto';

  @override
  String get convoyYouBadge => 'Voi';

  @override
  String convoyShareCopied(Object name, Object code) {
    return 'Copiato! Condividi: \"$name\" codice: $code';
  }

  @override
  String convoyShareClipboard(Object name, Object code) {
    return 'Convoglio CruizX: \"$name\" (codice: $code)';
  }

  @override
  String convoyPinMarkedBy(Object name) {
    return 'Contrassegnato da $name';
  }

  @override
  String get convoyNavigateToPin => 'Naviga qui';

  @override
  String get convoyEtaArrived => 'Arrivato!';

  @override
  String convoyEtaMinutes(Object minutes, Object time) {
    return '$minutes min · $time';
  }

  @override
  String convoyEtaHours(Object hours, Object minutes, Object time) {
    return '$hours h $minutes min · $time';
  }

  @override
  String get paywallTitle => 'Passa a CruizX Pro';

  @override
  String get paywallSubtitle => 'Nessun limite. Nessuna pubblicità. Accesso completo.';

  @override
  String get paywallPrice => '39 kr / mese';

  @override
  String get paywallUpgradeButton => 'Passa a Pro';

  @override
  String paywallLifetimeButton(Object price) {
    return 'Acquista Pro per sempre · $price';
  }

  @override
  String get paywallRestoreButton => 'Ripristina l\'acquisto';

  @override
  String paywallDisclosure(Object price) {
    return 'CruizX Pro · $price/mese · rinnovo automatico. Annulla in qualsiasi momento nelle Impostazioni almeno 24 ore prima del rinnovo. Addebitato sul tuo account ID Apple.';
  }

  @override
  String paywallDisclosureAndroid(Object price) {
    return 'CruizX Pro · $price/mese · rinnovo automatico. Gestito e fatturato tramite Stripe. Annulla in qualsiasi momento su cruizx.com o contattando l\'assistenza.';
  }

  @override
  String get paywallPriceOneTime => '249 kr';

  @override
  String paywallDisclosureOneTime(Object price) {
    return 'CruizX Pro · $price · acquisto una tantum. Addebitato una volta sul tuo ID Apple. Nessun abbonamento e nessun rinnovo.';
  }

  @override
  String get paywallFreeLabel => 'Gratuito';

  @override
  String get paywallProLabel => 'Pro';

  @override
  String get paywallStartTrialButton => 'Inizia la prova gratuita di 7 giorni';

  @override
  String paywallTrialNote(Object price) {
    return '7 giorni gratis, poi $price come acquisto una tantum.';
  }

  @override
  String get paywallFeatureRoutes => 'Percorsi giornalieri';

  @override
  String get paywallFreeRouteLimit => '4 percorsi';

  @override
  String get paywallProRouteLimit => 'Illimitato';

  @override
  String get paywallFeatureConvoy => 'Convoglio';

  @override
  String get paywallFreeConvoyLimit => '1 attivo, 2 membri';

  @override
  String get paywallProConvoyLimit => 'Illimitato';

  @override
  String get paywallFeatureAds => 'Annunci';

  @override
  String get paywallFreeAds => 'Mostrato';

  @override
  String get paywallProAds => 'Nessuno';

  @override
  String get paywallRouteLimitTitle => 'Limite del percorso raggiunto';

  @override
  String get paywallRouteLimitBody => 'Gli utenti gratuiti possono calcolare 4 percorsi al giorno. Passa a Pro per una navigazione illimitata.';

  @override
  String get paywallConvoyLimitTitle => 'Limite del convoglio raggiunto';

  @override
  String get paywallConvoyLimitBody => 'Gli utenti gratuiti possono far parte di un solo convoglio alla volta.';

  @override
  String get paywallMemberLimitTitle => 'Il convoglio è pieno';

  @override
  String get paywallMemberLimitBody => 'Gli utenti gratuiti possono unirsi solo a convogli con meno di 2 membri. Passa a Pro per un accesso illimitato.';

  @override
  String get paywallPurchaseSuccess => 'Ora sei un utente Pro!';

  @override
  String get paywallPurchaseFailed => 'Impossibile completare l\'acquisto. Controlla il tuo account App Store e riprova.';

  @override
  String get paywallRestoreSuccess => 'Acquisto ripristinato!';

  @override
  String get paywallLoginRequiredTitle => 'È richiesto l\'accesso';

  @override
  String get paywallLoginRequiredBody => 'Hai bisogno di un account per acquistare CruizX Pro. Crea un account gratuito nell\'app per continuare.';

  @override
  String get paywallLoginRequiredAction => 'OK';

  @override
  String get paywallRestoreNotFound => 'Nessun acquisto precedente trovato.';

  @override
  String get profileFreePlan => 'Piano gratuito';

  @override
  String get profileProPlan => 'Piano professionale';

  @override
  String get profileUpgradeToPro => 'Passa a Pro';

  @override
  String profileRoutesUsed(Object count, Object max) {
    return 'Percorsi oggi: $count / $max';
  }

  @override
  String get profileChangePhoto => 'Cambia foto del profilo';

  @override
  String get profileTakePhoto => 'Scatta una foto';

  @override
  String get profileChooseFromGallery => 'Scegli dalla galleria';

  @override
  String get profilePhotoUploadFailed => 'Impossibile caricare la foto';

  @override
  String get parentModeTitle => 'Modalità genitore';

  @override
  String get parentModeDescription => 'Lascia che un genitore segua la tua guida in tempo reale.';

  @override
  String get parentModeLoginRequired => 'Devi aver effettuato l\'accesso per utilizzare la modalità genitore.';

  @override
  String get parentModeEnable => 'Abilita la modalità genitore';

  @override
  String get parentModeEnabledSubtitle => 'I genitori possono seguire la tua guida';

  @override
  String get parentModeDisabledSubtitle => 'Nessuna condivisione attiva';

  @override
  String get parentModeInviteCode => 'Codice invito';

  @override
  String get parentModeInviteCodeSubtitle => 'Condividi questo codice con i tuoi genitori per collegare il loro account.';

  @override
  String get parentModeCopyCode => 'Copia';

  @override
  String get parentModeShareCode => 'Condividere';

  @override
  String get parentModeCodeCopied => 'Codice copiato!';

  @override
  String get parentModeShareSubject => 'Codice genitore CruizX';

  @override
  String parentModeShareMessage(Object code) {
    return 'CIAO! Usa questo codice per seguire la mia guida in CruizX: $code';
  }

  @override
  String get parentModeLinkedParents => 'Genitori collegati';

  @override
  String get parentModeNoParentsLinked => 'Nessun genitore ancora collegato. Condividi il tuo codice!';

  @override
  String get parentModeUnlinkTitle => 'Rimuovere il genitore?';

  @override
  String parentModeUnlinkMessage(Object name) {
    return 'Vuoi rimuovere $name come genitore? Non saranno più in grado di seguire la tua guida.';
  }

  @override
  String get parentModeUnlink => 'Rimuovere';

  @override
  String get parentModeShareSettings => 'Cosa condividere';

  @override
  String get parentModeShareLocation => 'Condividi posizione';

  @override
  String get parentModeShareLocationSubtitle => 'Mostra dove ti trovi sulla mappa';

  @override
  String get parentModeShareSpeed => 'Condividi la velocità';

  @override
  String get parentModeShareSpeedSubtitle => 'Mostra la tua velocità attuale';

  @override
  String get parentModeAlertSettings => 'Avvisi ai genitori';

  @override
  String get parentModeSpeedAlert => 'Avviso di velocità';

  @override
  String parentModeSpeedAlertSubtitle(Object limit) {
    return 'Avvisa quando la velocità supera $limit km/h';
  }

  @override
  String get parentModeSpeedLimit => 'Limite';

  @override
  String get parentModeNightAlert => 'Avviso di guida notturna';

  @override
  String parentModeNightAlertSubtitle(Object start, Object end) {
    return 'Avvisa quando guidi tra $start–$end';
  }

  @override
  String get cancel => 'Cancellare';

  @override
  String get login => 'Login';

  @override
  String get parentDashboardTitle => 'Dashboard genitori';

  @override
  String get parentDashboardMapTab => 'Mappa';

  @override
  String get parentDashboardAlertsTab => 'Avvisi';

  @override
  String get parentDashboardAddChild => 'Aggiungi bambino';

  @override
  String get parentDashboardOnline => 'In linea';

  @override
  String get parentDashboardOffline => 'Non in linea';

  @override
  String get parentDashboardNoAlerts => 'Nessun avviso nelle ultime 24 ore';

  @override
  String get parentDashboardNoChildren => 'Nessun bambino ancora collegato';

  @override
  String get parentDashboardNoChildrenHint => 'Aggiungi un bambino inserendo il codice di invito dalla modalità genitore CruizX.';

  @override
  String get parentDashboardEnterCode => 'Inserisci il codice di invito';

  @override
  String get parentDashboardEnterCodeHint => 'Chiedi a tuo figlio di condividere il codice di invito di 6 caratteri dalle impostazioni della modalità genitore.';

  @override
  String get parentDashboardLink => 'Collegamento';

  @override
  String get parentDashboardLinkSuccess => 'Collegato con successo!';

  @override
  String get parentDashboardLinkFailed => 'Impossibile trovare il bambino con quel codice. Controlla il codice e riprova.';

  @override
  String get parentDashboardLinkSelf => 'Non puoi collegarti al tuo account. Chiedi a tuo figlio di condividere il codice dal suo account.';

  @override
  String get parentDashboardSpeedingAlert => 'Avviso di velocità';

  @override
  String parentDashboardSpeedingDetail(Object name, Object speed, Object limit) {
    return '$name ha guidato a $speed km/h (limite: $limit km/h)';
  }

  @override
  String get parentDashboardNightAlert => 'Guida notturna';

  @override
  String parentDashboardNightDetail(Object name) {
    return '$name sta guidando di notte';
  }

  @override
  String get parentDashboardViewChild => 'Visualizza come genitore';

  @override
  String get settingsVoiceNavigation => 'Navigazione vocale';

  @override
  String get settingsVoiceNavigationSubtitle => '';

  @override
  String get voiceTurnLeft => 'Girare a sinistra';

  @override
  String get voiceTurnRight => 'Girare a destra';

  @override
  String get voiceTurnSharpLeft => 'Girare tutto a sinistra';

  @override
  String get voiceTurnSharpRight => 'Girare tutto a destra';

  @override
  String get voiceTurnSlightLeft => 'Girare leggermente a sinistra';

  @override
  String get voiceTurnSlightRight => 'Girare leggermente a destra';

  @override
  String get voiceContinue => 'Prosegui dritto';

  @override
  String get voiceRoundabout => 'Entra nella rotonda';

  @override
  String get voiceDestination => 'Hai raggiunto la tua destinazione';

  @override
  String voiceInMeters(Object meters) {
    return 'Tra $meters metri';
  }

  @override
  String voiceInKm(Object km) {
    return 'Tra $km chilometri';
  }

  @override
  String get mfaSetupTitle => 'Abilita l\'autenticazione a due fattori';

  @override
  String get mfaSetupSubtitle => 'Scansiona il codice QR con un\'app di autenticazione come Google Authenticator o Authy';

  @override
  String get mfaScanQr => 'Scansiona il codice qui sopra e inserisci il codice di 6 cifre qui sotto';

  @override
  String get mfaVerifyButton => 'Verificare';

  @override
  String get mfaVerifyTitle => 'Autenticazione a due fattori';

  @override
  String get mfaVerifySubtitle => 'Inserisci il codice di 6 cifre dalla tua app di autenticazione';

  @override
  String get mfaInvalidCode => 'Codice non valido, riprova';

  @override
  String get mfaCancel => 'Annulla ed esci';

  @override
  String get mfaProfileTitle => 'Autenticazione a due fattori';

  @override
  String get mfaStatusOn => 'Abilitato: il tuo account è protetto';

  @override
  String get mfaStatusOff => 'Disabilitato';

  @override
  String get mfaTurnOn => 'Abilitare';

  @override
  String get mfaTurnOff => 'Spegnere';

  @override
  String get mfaDisableTitle => 'Disattivare 2FA?';

  @override
  String get mfaDisableBody => 'Il tuo account sarà meno sicuro senza l\'autenticazione a due fattori.';

  @override
  String get mfaDisableConfirm => 'Spegnere';

  @override
  String get mfaShowManualKey => 'Non riesci a eseguire la scansione? Mostra chiave manualmente';

  @override
  String get mfaHideManualKey => 'Nascondi chiave manuale';

  @override
  String get mfaKeyCopied => 'Chiave copiata';

  @override
  String get mfaRecommendTitle => 'Proteggi il tuo account';

  @override
  String get mfaRecommendBody => 'Ti consigliamo di abilitare l\'autenticazione a due fattori per proteggere il tuo account. Puoi utilizzare un\'app di autenticazione come Google Authenticator o Authy.';

  @override
  String get mfaRecommendSetup => 'Abilita ora';

  @override
  String get mfaRecommendLater => 'Dopo';

  @override
  String get favHome => 'Casa';

  @override
  String get favSchool => 'Scuola';

  @override
  String get favWork => 'Lavoro';

  @override
  String get favAddTitle => 'Salva posto';

  @override
  String get favLabelHint => 'Nome (ad esempio Amico)';

  @override
  String get favSaved => 'Luogo salvato';

  @override
  String get favDeleted => 'Luogo rimosso';

  @override
  String favDeleteConfirm(Object name) {
    return 'Rimuovere $name?';
  }

  @override
  String favSetAs(Object type) {
    return 'Salva come $type';
  }

  @override
  String get favCustom => 'Altro preferito';

  @override
  String get ttsVoiceHint => 'Suggerimento: scarica voci migliori in Impostazioni → Accessibilità → Contenuto parlato → Voci';

  @override
  String get ttsVoiceHintDismiss => 'OK';

  @override
  String get settingsVectorMap => 'Mappa vettoriale';

  @override
  String get settingsVectorMapOn => 'Rendering nitido a tutti i livelli di zoom, zoom fluido';

  @override
  String get settingsVectorMapOff => 'Standard: veloce e memorizzato nella cache offline';

  @override
  String get publicGatheringStartTime => 'Ora di inizio';

  @override
  String get publicGatheringEndTime => 'Ora di fine';

  @override
  String get publicGatheringScheduleInvalid => 'L\'ora di fine deve essere successiva all\'ora di inizio.';

  @override
  String get publicGatheringEndAction => 'Fine dell\'incontro';

  @override
  String get publicGatheringDeleteAction => 'Elimina incontro';

  @override
  String get publicGatheringEndConfirm => 'Terminare l\'incontro adesso? I partecipanti non saranno più in grado di trovarlo.';

  @override
  String get publicGatheringDeleteConfirm => 'Eliminare definitivamente questo incontro? Questa operazione non può essere annullata.';

  @override
  String get publicGatheringReportAction => 'Segnala incontro';

  @override
  String get publicGatheringBlockAction => 'Blocca incontro';

  @override
  String get publicGatheringReportParticipant => 'Segnala partecipante';

  @override
  String get publicGatheringBlockParticipant => 'Blocca partecipante';

  @override
  String get publicGatheringReportReason => 'Cosa vorresti segnalare?';

  @override
  String get publicGatheringReportSent => 'La tua segnalazione è stata inviata.';

  @override
  String get publicGatheringBlocked => 'I contenuti bloccati non verranno più visualizzati.';

  @override
  String get reportReasonInappropriate => 'Contenuti inappropriati';

  @override
  String get reportReasonHarassment => 'Molestie';

  @override
  String get reportReasonDangerous => 'Comportamento pericoloso';

  @override
  String get reportReasonSpam => 'Spam o fuorvianti';

  @override
  String get reportReasonOther => 'Altro';

  @override
  String get publicGatheringNearbyNotifications => 'Notifiche di incontri nelle vicinanze';

  @override
  String get publicGatheringNearbyNotificationsSubtitle => 'Avvisami una volta quando inizia un incontro pubblico entro 25 km entro 24 ore.';

  @override
  String get publicGatheringUpcoming => 'Prossimamente';

  @override
  String get publicGatheringStarted => 'In corso';

  @override
  String get aiRouteButton => 'Controlla percorso con IA';

  @override
  String get aiRouteTitle => 'Analisi percorso CruizX IA';

  @override
  String get aiConsentTitle => 'Usare l’analisi IA del percorso?';

  @override
  String get aiConsentBody => 'CruizX utilizza dati come distanza, durata, tipo di veicolo, nomi delle strade e numero di avvisi per analizzare il percorso. La tua posizione esatta, le coordinate della destinazione e la tua identità non vengono condivise. L’analisi può contenere errori e non modifica mai il percorso.';

  @override
  String get aiConsentAccept => 'Accetta e continua';

  @override
  String get aiConsentDecline => 'Non ora';

  @override
  String get aiSignInRequired => 'Accedi per usare l’analisi IA del percorso.';

  @override
  String get aiLoading => 'Controllo del percorso…';

  @override
  String get aiUnavailable => 'L’analisi IA non è disponibile al momento. Il percorso non è cambiato.';

  @override
  String get aiDailyLimit => 'Hai raggiunto il limite giornaliero di analisi IA.';

  @override
  String get aiHighlights => 'Aspetti positivi';

  @override
  String get aiCautions => 'Da controllare';

  @override
  String get aiRecommendation => 'Raccomandazione';

  @override
  String get aiDisclaimer => 'Riepilogo IA basato solo sui dati disponibili. Segui la segnaletica e le condizioni stradali attuali.';

  @override
  String get aiReport => 'Segnala risposta';

  @override
  String get aiReportTitle => 'Perché segnali questa risposta?';

  @override
  String get aiReportIncorrect => 'Informazioni errate';

  @override
  String get aiReportUnsafe => 'Consiglio non sicuro';

  @override
  String get aiReportInappropriate => 'Contenuto inappropriato';

  @override
  String get aiReportOther => 'Altro problema';

  @override
  String get aiReportSent => 'Grazie. La risposta IA è stata segnalata.';
}
