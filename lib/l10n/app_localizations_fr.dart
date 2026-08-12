// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'CruizX';

  @override
  String get navMap => 'Carte';

  @override
  String get navAlerts => 'Alertes';

  @override
  String get navConvoy => 'Convoi';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get splashPreparingStartup => 'Préparation du démarrage...';

  @override
  String get splashLoadingCoreModules => 'Chargement des modules principaux...';

  @override
  String get splashInitializingAccountSession =>
      'Initialisation de la session...';

  @override
  String get splashLoadingPreferences => 'Chargement des préférences...';

  @override
  String get splashFinalizingStartup => 'Finalisation du démarrage...';

  @override
  String get splashReady => 'Prêt';

  @override
  String get splashVersionLine => 'v1.2.0 | CruizX by KimTechTool';

  @override
  String get a11yCenterOnLocation => 'Centrer la carte sur ma position';

  @override
  String get a11yStopFollowingLocation => 'Arrêter de suivre ma position';

  @override
  String get a11ySwitchTo2d => 'Passer à la carte 2D';

  @override
  String get a11ySwitchTo3d => 'Passer à la carte 3D';

  @override
  String get a11yUseDarkMap => 'Utiliser la carte sombre';

  @override
  String get a11yUseLightMap => 'Utiliser la carte claire';

  @override
  String get a11yEnableVoiceNavigation => 'Activer la navigation vocale';

  @override
  String get a11yDisableVoiceNavigation => 'Désactiver la navigation vocale';

  @override
  String get a11yDismissAlert => 'Fermer l’alerte';

  @override
  String get a11yClearSearch => 'Effacer la recherche';

  @override
  String get a11yOpenSearch => 'Ouvrir la recherche d’adresse';

  @override
  String get a11yAddFavorite => 'Ajouter un lieu favori';

  @override
  String get a11yConfirmAlert => 'Confirmer l’alerte';

  @override
  String get alertsTitle => 'Alertes communautaires';

  @override
  String get alertsSubtitle =>
      'Signalez et consultez les dangers routiers, contrôles et conditions de route.';

  @override
  String get convoyRequiresSignInTitle => 'Le convoi nécessite une connexion';

  @override
  String get convoyRequiresSignInSubtitle =>
      'Connectez-vous ou créez un compte ici pour créer des groupes de convoi et voir les positions en direct.';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'Créer un compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get signInEmailDialogTitle => 'Connexion par e-mail OTP';

  @override
  String get signUpEmailDialogTitle => 'Créer un compte avec e-mail OTP';

  @override
  String get signInEmailFieldLabel => 'E-mail';

  @override
  String get signInEmailHint => 'nom@exemple.fr';

  @override
  String get signInSendOtp => 'Envoyer le code';

  @override
  String get signUpSendOtp => 'Envoyer le code de création';

  @override
  String get signInOtpFieldLabel => 'Code OTP';

  @override
  String get signInOtpHint => 'Code à 6 chiffres';

  @override
  String get signInVerifyOtp => 'Vérifier le code';

  @override
  String get signInOtpSent => 'Code OTP envoyé à votre e-mail.';

  @override
  String get signUpOtpSent =>
      'Code de création de compte envoyé à votre e-mail.';

  @override
  String get signInOtpInvalid =>
      'Impossible de vérifier le code OTP. Vérifiez votre code et réessayez.';

  @override
  String get signUpNoAccountAction => 'Pas de compte ? Créez-en un';

  @override
  String get signUpHaveAccountAction =>
      'Vous avez déjà un compte ? Connectez-vous';

  @override
  String get authGenericError => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get authWelcomeBack => 'Bon retour sur CruizX';

  @override
  String get authRegisterSubtitle => 'Rejoignez la communauté CruizX';

  @override
  String get authEmailLabel => 'Adresse e-mail';

  @override
  String get authEmailRequired => 'Entrez votre adresse e-mail';

  @override
  String get authEmailInvalid => 'E-mail invalide';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authPasswordRequired => 'Entrez votre mot de passe';

  @override
  String get authPasswordMinLength =>
      'Au moins 6 caractères, un chiffre et un caractère spécial';

  @override
  String get authConfirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get authConfirmPasswordRequired => 'Confirmez votre mot de passe';

  @override
  String get authPasswordsDoNotMatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get authDisplayNameLabel => 'Nom d\'affichage';

  @override
  String get authDisplayNameRequired => 'Entrez votre nom';

  @override
  String get authNoAccountPrompt => 'Pas de compte ? ';

  @override
  String get authAlreadyHaveAccountPrompt => 'Vous avez déjà un compte ? ';

  @override
  String get authCancel => 'Annuler';

  @override
  String get authForgotPasswordLink => 'Mot de passe oublié ?';

  @override
  String get authForgotPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get authForgotPasswordDescription =>
      'Entrez votre adresse e-mail et nous vous enverrons un lien pour réinitialiser votre mot de passe.';

  @override
  String get authForgotPasswordButton => 'Envoyer le lien';

  @override
  String get authForgotPasswordSuccess =>
      'Si le compte existe, nous avons envoyé un lien de réinitialisation à votre e-mail.';

  @override
  String get authResetPasswordTitle => 'Nouveau mot de passe';

  @override
  String get authResetPasswordDescription =>
      'Entrez votre nouveau mot de passe ci-dessous.';

  @override
  String get authNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get authResetPasswordButton => 'Enregistrer le mot de passe';

  @override
  String get authResetPasswordSuccess => 'Votre mot de passe a été modifié.';

  @override
  String get authErrorAllFieldsRequired => 'Tous les champs sont obligatoires.';

  @override
  String get authErrorPasswordTooShort =>
      'Le mot de passe doit contenir au moins 6 caractères, dont un chiffre et un caractère spécial.';

  @override
  String get authErrorConfirmEmail =>
      'Vérifiez votre e-mail pour confirmer votre compte, puis connectez-vous.';

  @override
  String get authEmailConfirmedTitle => 'Adresse e-mail confirmée';

  @override
  String get authEmailConfirmedBody =>
      'Votre adresse e-mail a été confirmée. Vous êtes maintenant connecté.';

  @override
  String get authErrorEmailAndPasswordRequired =>
      'Entrez votre e-mail et votre mot de passe.';

  @override
  String get authErrorInvalidCredentials => 'E-mail ou mot de passe incorrect.';

  @override
  String get authErrorEmailAlreadyInUse =>
      'Un compte avec cette adresse e-mail existe déjà.';

  @override
  String get authErrorInvalidEmail =>
      'L’adresse e-mail n’est pas valide. Vérifiez-la et réessayez.';

  @override
  String get authErrorRateLimited =>
      'Trop de tentatives en peu de temps. Patientez un instant et réessayez.';

  @override
  String get authErrorSignUpDisabled =>
      'La création de nouveaux comptes est momentanément indisponible. Contactez l’assistance CruizX.';

  @override
  String get authErrorEmailDeliveryFailed =>
      'L’e-mail de confirmation n’a pas pu être envoyé. Réessayez dans quelques instants.';

  @override
  String get authErrorNetworkUnavailable =>
      'Impossible de se connecter au service de compte. Vérifiez votre connexion Internet et réessayez.';

  @override
  String get convoyRealtimeBackendMissing =>
      'Le convoi en temps réel n\'est pas configuré. Ajoutez la configuration backend pour partager les positions en direct entre utilisateurs.';

  @override
  String get convoyModeTitle => 'Mode convoi';

  @override
  String get convoyModeSubtitle =>
      'Créez un groupe de conduite avec une destination partagée et des positions en direct.';

  @override
  String get convoyCreateButton => 'Créer un convoi';

  @override
  String get publicGatheringsTitle => 'Rassemblements publics';

  @override
  String get publicGatheringsSubtitle =>
      'Trouvez un point de rencontre, rejoignez publiquement et choisissez si votre position en direct est visible.';

  @override
  String get publicGatheringsMineTab => 'Les miens';

  @override
  String get publicGatheringsPublicTab => 'Publics';

  @override
  String get publicGatheringsEmpty =>
      'Aucun rassemblement public actif pour le moment.';

  @override
  String get publicGatheringCreateButton => 'Créer un rassemblement public';

  @override
  String get publicGatheringCreateTitle => 'Nouveau rassemblement public';

  @override
  String get publicGatheringPlaceHint => 'Point de rencontre, par ex. la place';

  @override
  String get publicGatheringLocationExplanation =>
      'Le rassemblement est placé à votre position actuelle et reste actif 6 heures. Le partage de position en direct est facultatif.';

  @override
  String get publicGatheringLocationRequired =>
      'L’accès à la position est requis pour définir le point de rencontre.';

  @override
  String get publicGatheringPublish => 'Publier';

  @override
  String get publicGatheringStartSharing => 'Partager ma position en direct';

  @override
  String get publicGatheringStopSharing =>
      'Arrêter de partager ma position en direct';

  @override
  String get convoyOpenButton => 'Ouvrir';

  @override
  String get convoyJoinButton => 'Rejoindre';

  @override
  String get convoyLeaveButton => 'Quitter';

  @override
  String get convoyJoinFirstHint =>
      'Rejoignez d\'abord le convoi, puis appuyez pour ouvrir le chat et la carte.';

  @override
  String get convoyJoinByCodeTitle => 'Rejoindre un convoi';

  @override
  String get convoyJoinByCodeHint => 'Entrez le code du convoi reçu';

  @override
  String get convoyJoinWithCodeButton => 'Rejoindre';

  @override
  String get convoyJoinByCodeNotFound => 'Aucun convoi trouvé avec ce code.';

  @override
  String convoyJoinByCodeSuccess(String name) {
    return 'Vous avez rejoint $name !';
  }

  @override
  String get convoyInviteButton => 'Inviter';

  @override
  String get convoyTabMap => 'Carte';

  @override
  String get convoyTabChat => 'Chat';

  @override
  String get convoyMapHint =>
      'Appuyez sur la carte pour placer un repère partagé.';

  @override
  String get convoyRecenterTooltip => 'Recentrer et suivre ma position';

  @override
  String get convoyPinDialogTitle => 'Ajouter un repère';

  @override
  String get convoyPinLabel => 'Nom du repère';

  @override
  String get convoyPinHint => 'ex. Rendez-vous ici';

  @override
  String get convoyPinAdd => 'Ajouter le repère';

  @override
  String get convoyHazardPolice => 'Police';

  @override
  String get convoyHazardRoadwork => 'Travaux';

  @override
  String get convoyHazardAccident => 'Accident';

  @override
  String get convoyHazardTrafficJam => 'Embouteillage';

  @override
  String get convoyHazardSpeedCamera => 'Radar';

  @override
  String get convoyHazardCustom => 'Repère personnalisé';

  @override
  String get convoyPoiMeetup => 'Point de rendez-vous';

  @override
  String get convoyPoiMeetupSubtitle =>
      'Marquez un lieu clair où le convoi doit se regrouper';

  @override
  String get convoyPoiParking => 'Parking';

  @override
  String get convoyPoiFoodStop => 'Pause repas';

  @override
  String get convoyPoiCharging => 'Recharge';

  @override
  String get routeStopFuel => 'Carburant';

  @override
  String get routeStopCafe => 'Café';

  @override
  String get routeStopGrocery => 'Courses';

  @override
  String get convoyPoiHangout => 'Lieu de rassemblement';

  @override
  String get convoyChatEmpty => 'Aucun message pour l\'instant.';

  @override
  String get convoyChatPlaceholder => 'Écrire un message...';

  @override
  String get convoyChatSend => 'Envoyer';

  @override
  String get convoyNameDialogTitle => 'Créer un convoi';

  @override
  String get convoyNameFieldLabel => 'Nom du convoi';

  @override
  String get convoyNameHint => 'ex. Balade du vendredi soir';

  @override
  String get convoyCreateConfirm => 'Créer';

  @override
  String get convoyCreateCancel => 'Annuler';

  @override
  String get convoyListEmpty =>
      'Aucun convoi pour l\'instant. Créez le premier.';

  @override
  String get convoyListEmptyMine => 'Vous n\'avez rejoint aucun convoi.';

  @override
  String get convoyFilterAll => 'Tous';

  @override
  String get convoyFilterMine => 'Mes convois';

  @override
  String convoyMembers(Object count) {
    return '$count membres';
  }

  @override
  String get convoyMemberMe => 'Moi';

  @override
  String convoyMemberStaleTime(Object mins) {
    return 'il y a $mins min';
  }

  @override
  String convoyCreatedBy(Object leader) {
    return 'Créé par $leader';
  }

  @override
  String get profileTitle => 'Profil & Statistiques';

  @override
  String get profileNotSignedIn => 'Vous n\'êtes pas connecté.';

  @override
  String get profileSignInInConvoyHint =>
      'La connexion est disponible dans l\'onglet Convoi.';

  @override
  String profileSignedInAs(Object name) {
    return 'Connecté en tant que : $name';
  }

  @override
  String get profileDefaultName => 'Conducteur CruizX';

  @override
  String get profileSignedIn => 'Connecté';

  @override
  String get profileStatsTitle => 'Statistiques';

  @override
  String get profileStatsConvoys => 'Convois effectués';

  @override
  String get profileStatsTotalDistance => 'Distance totale';

  @override
  String get profileStatsSpeedViolations => 'Excès de vitesse';

  @override
  String get profileVehicleTitle => 'Mon véhicule';

  @override
  String get profileVehicleElectric => 'Véhicule électrique';

  @override
  String get profileVehicleElectricSubtitle =>
      'Afficher les bornes de recharge sur la carte';

  @override
  String get profileVehicleStuddedTires => 'Pneus cloutés';

  @override
  String get profileVehicleStuddedTiresSubtitle =>
      'Éviter les rues interdites aux pneus cloutés';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsLanguageLabel => 'Langue';

  @override
  String get settingsLanguageSystem => 'Par défaut du système';

  @override
  String get settingsLanguageEnglish => 'Anglais';

  @override
  String get settingsLanguageSwedish => 'Suédois';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsLanguageNorwegian => 'Norvégien';

  @override
  String get settingsLanguageDanish => 'Danois';

  @override
  String get settingsLanguageFinnish => 'Finnois';

  @override
  String get settingsLanguageSpanish => 'Espagnol';

  @override
  String get settingsLanguageItalian => 'Italien';

  @override
  String get settingsCountryLabel => 'Pays (règles de circulation)';

  @override
  String get settingsCountrySweden => '🇸🇪 Suède';

  @override
  String get settingsCountryNorway => '🇳🇴 Norvège';

  @override
  String get settingsCountryDenmark => '🇩🇰 Danemark';

  @override
  String get settingsCountryFinland => '🇫🇮 Finlande';

  @override
  String get settingsCountryFrance => '🇫🇷 France';

  @override
  String get settingsCountrySpain => '🇪🇸 Espagne';

  @override
  String get settingsCountryItaly => '🇮🇹 Italie';

  @override
  String get settingsCountryUnitedKingdom => '🇬🇧 Royaume-Uni';

  @override
  String get settingsCountryHint =>
      'Les limites de vitesse et règles routières s\'adaptent au pays sélectionné.';

  @override
  String settingsLanguageCurrentlyUsing(Object mode) {
    return 'Utilisation actuelle : $mode';
  }

  @override
  String get settingsVehicleTypeLabel => 'Type de véhicule';

  @override
  String get settingsVehicleAtractor => 'Tracteur A';

  @override
  String get settingsVehicleLowVehicle => 'Véhicule surbaissé';

  @override
  String get settingsVehicleMopedCar => 'Voiture sans permis';

  @override
  String get settingsVehicleMopedClassI => 'Cyclomoteur classe I';

  @override
  String get settingsVehicleMopedClassII => 'Cyclomoteur classe II (25 km/h)';

  @override
  String get settingsVehicleElectricScooter => 'Trottinette électrique';

  @override
  String get settingsElectricScooterLegalNotice =>
      'Utilisez uniquement une trottinette électrique homologuée là où les règles locales l’autorisent. La signalisation, les règles municipales et les zones de location priment toujours sur l’itinéraire.';

  @override
  String get settingsEscooterRentalOnlyNotice =>
      'Au Royaume-Uni, seules les trottinettes électriques de location homologuées sont autorisées sur la voie publique. Les trottinettes privées ne peuvent être utilisées que sur un terrain privé avec l’accord du propriétaire.';

  @override
  String get settingsVehicleTractor => 'Tracteur';

  @override
  String get settingsSpeedUnitKmh => 'km/h';

  @override
  String get settingsSpeedUnitMph => 'mph';

  @override
  String settingsMaxSpeedWithUnit(Object value, Object unit) {
    return 'Vitesse max : $value $unit';
  }

  @override
  String get settingsProCardTitle => 'CruizX Pro';

  @override
  String get settingsProStatusActive => 'Actif';

  @override
  String get settingsProStatusInactive => 'Non actif';

  @override
  String get settingsProDescriptionActive =>
      'Vous avez accès à toutes les fonctionnalités Pro.';

  @override
  String get settingsProDescriptionInactive =>
      'Débloquez toutes les fonctionnalités avec CruizX Pro.';

  @override
  String get settingsProFeatureRoutes => 'Plus d’analyses d’itinéraire par IA';

  @override
  String get settingsProFeatureConvoy => 'Membres de convoi illimités';

  @override
  String get settingsProFeatureAds => 'Aucune publicité';

  @override
  String get settingsProFeatureSupport => 'Support prioritaire';

  @override
  String get settingsProSubscriptionNote =>
      'Abonnement : CruizX Pro Mensuel (1 mois). Le paiement est facturé sur votre identifiant Apple et se renouvelle automatiquement sauf annulation au moins 24 heures avant la fin de la période.';

  @override
  String settingsProPricePerMonth(Object price) {
    return '$price / mois';
  }

  @override
  String settingsProPriceOneTime(Object price) {
    return '$price';
  }

  @override
  String get settingsProOneTimeNote =>
      'Achat unique : CruizX Pro (à vie). Le paiement est débité une seule fois via la boutique d’applications. Aucun abonnement ni renouvellement.';

  @override
  String get settingsPrivacyPolicyLabel => 'Politique de confidentialité';

  @override
  String get settingsTermsOfUseLabel => 'Conditions d\'utilisation (EULA)';

  @override
  String get settingsSupportLabel => 'Support';

  @override
  String get supportChatTitle => 'Chat en direct avec l’assistance';

  @override
  String get supportChatReplyTime => 'Réponse sous 24 heures';

  @override
  String get supportChatWelcome =>
      'Bonjour ! Comment pouvons-nous vous aider avec CruizX ? Écrivez votre message ici et nous vous répondrons dès que possible.';

  @override
  String get supportChatGuestNotice =>
      'Vous discutez en tant qu’invité. Cette conversation est enregistrée de façon privée sur cet appareil.';

  @override
  String get supportChatLoginRequired =>
      'Connectez-vous pour démarrer une conversation privée avec l’assistance et consulter vos anciens messages.';

  @override
  String get supportChatLoginAction => 'Se connecter';

  @override
  String get supportChatMessageHint => 'Écrivez un message…';

  @override
  String get supportChatSend => 'Envoyer le message';

  @override
  String get supportChatSendFailed =>
      'Le message n’a pas pu être envoyé. Réessayez.';

  @override
  String get supportChatUnavailable =>
      'Le chat d’assistance est indisponible pour le moment. Réessayez plus tard.';

  @override
  String get supportChatTeam => 'Assistance CruizX';

  @override
  String get supportChatYou => 'Vous';

  @override
  String get settingsLinkOpenFailed =>
      'Impossible d\'ouvrir le lien pour le moment.';

  @override
  String get settingsRestorePurchaseFailed =>
      'Impossible de restaurer l\'achat.';

  @override
  String get settingsMapMarkerLabel => 'Marqueur de carte';

  @override
  String get settingsMapMarkerCategoryClassic => 'Classiques';

  @override
  String get settingsMapMarkerCategoryMicrocar => 'Voiture sans permis';

  @override
  String get settingsMapMarkerCategoryEpa => 'EPA';

  @override
  String get settingsMapMarkerCategoryLigier => 'Ligier';

  @override
  String get settingsMapMarkerCategoryAixam => 'Aixam';

  @override
  String get settingsMapMarkerCategoryPickup => 'Pickup';

  @override
  String get settingsMapMarkerCategoryAtractor => 'Tracteur A';

  @override
  String get settingsMapMarkerCategoryTractor => 'Tracteur';

  @override
  String get settingsMapMarkerArrow => 'Flèche';

  @override
  String get settingsMapMarkerCompass => 'Boussole';

  @override
  String get settingsMapMarkerTriangle => 'Triangle';

  @override
  String get settingsMapMarkerDot => 'Point';

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
  String get settingsMapMarkerMopeds => 'Cyclomoteurs';

  @override
  String get settingsMapMarkerScooter => 'Scooter';

  @override
  String get settingsMapMarkerCrossMoped => 'Cyclomoteur cross';

  @override
  String get settingsMapMarkerTractor => 'Traktor';

  @override
  String get settingsColorRed => 'Rouge';

  @override
  String get settingsColorBlue => 'Bleu';

  @override
  String get settingsColorBlack => 'Noir';

  @override
  String get settingsColorWhite => 'Blanc';

  @override
  String get settingsColorGold => 'Or';

  @override
  String get settingsColorSilver => 'Argent';

  @override
  String get settingsColorGreen => 'Vert';

  @override
  String get settingsColorGraphite => 'Graphite';

  @override
  String get settingsColorYellow => 'Jaune';

  @override
  String get settingsColorOrange => 'Orange';

  @override
  String get settingsColorPink => 'Rose';

  @override
  String get navigationTitle => 'Navigation virage par virage';

  @override
  String get navigationSubtitle =>
      'Itinéraire, prochain virage et heure d\'arrivée optimisés pour les véhicules lents.';

  @override
  String get mapStartingGps => 'Démarrage du GPS...';

  @override
  String get mapTapToSelectDestination =>
      'Appuyez sur la carte pour choisir une destination';

  @override
  String get mapAddressFieldHint =>
      'Rechercher une adresse (ex. Rue de Rivoli 10, Paris)';

  @override
  String get mapSearchingAddress => 'Recherche d\'adresse...';

  @override
  String get mapAddressNotFound => 'Aucune adresse trouvée. Réessayez.';

  @override
  String get mapAddressLookupFailed =>
      'Impossible de rechercher l\'adresse pour le moment';

  @override
  String get mapLocationServicesDisabled =>
      'Les services de localisation sont désactivés';

  @override
  String get mapLocationPermissionMissing =>
      'L\'autorisation de localisation est manquante';

  @override
  String get mapGpsActive => 'GPS actif';

  @override
  String get mapGpsUnavailable =>
      'Le GPS n\'est pas disponible dans cet environnement';

  @override
  String get mapWaitingForGps =>
      'En attente de la position GPS avant le calcul de l\'itinéraire';

  @override
  String get mapCalculatingRoute => 'Calcul de l\'itinéraire...';

  @override
  String mapRouteReady(Object distance, Object minutes) {
    return 'Itinéraire prêt : $distance km • $minutes min';
  }

  @override
  String get mapRouteFailed =>
      'Impossible de créer l\'itinéraire pour le moment';

  @override
  String get mapRemaining => 'restant';

  @override
  String get mapRouteNoRouteFound =>
      'Aucun itinéraire trouvé entre les points sélectionnés';

  @override
  String get mapRouteProviderUnavailable =>
      'Le service de routage est indisponible pour le moment';

  @override
  String get mapRouteMissingApiKey =>
      'Le routage n\'est pas configuré sur le backend (clé API manquante)';

  @override
  String get mapRouteInvalidGeometry =>
      'Les données d\'itinéraire du serveur sont invalides';

  @override
  String get mapRouteUnknownProvider =>
      'Le fournisseur de routage n\'est pas correctement configuré';

  @override
  String get mapRouteTooFastForVehicle =>
      'Itinéraire refusé : la vitesse moyenne estimée est trop élevée pour ce type de véhicule.';

  @override
  String get mapRouteNotAllowedForVehicle =>
      'Aucun itinéraire légalement conforme trouvé pour ce type de véhicule.';

  @override
  String get routeStopSheetSubtitle =>
      'Arrêts les plus proches le long de l\'itinéraire';

  @override
  String get routeStopNearbySubtitle =>
      'Options les plus proches autour de vous';

  @override
  String get routeStopEmpty =>
      'Aucun bon arrêt près de l\'itinéraire pour le moment.';

  @override
  String get routeStopNearbyEmpty =>
      'Aucune bonne option près de vous pour le moment.';

  @override
  String get searchSaved => 'Enregistré';

  @override
  String get searchRecent => 'Récent';

  @override
  String get searchNew => 'Nouveau';

  @override
  String routeStopFromRoute(Object distance) {
    return '$distance de l\'itinéraire';
  }

  @override
  String routeStopAway(Object distance) {
    return 'à $distance';
  }

  @override
  String get routeBlockedTitle => 'Itinéraire non disponible';

  @override
  String routeBlockedBody(Object vehicleType) {
    return 'Aucun itinéraire légal n\'a été trouvé vers cette destination pour votre $vehicleType. La destination se trouve peut-être sur ou n\'est accessible que par des routes interdites à ce type de véhicule (ex: autoroutes).';
  }

  @override
  String get routeBlockedOk => 'OK';

  @override
  String get routeBlockedTryOther => 'Essayer une autre destination';

  @override
  String get routeFallbackTitle => 'Itinéraire non vérifié trouvé';

  @override
  String routeFallbackBody(Object vehicleType) {
    return 'Nous avons trouvé un itinéraire possible, mais il n\'a pas pu être entièrement vérifié pour votre $vehicleType. Il peut inclure des routes à contrôler. Respectez toujours la signalisation et les règles locales.';
  }

  @override
  String get routeFallbackCancel => 'Annuler';

  @override
  String get routeFallbackUse => 'Afficher quand même';

  @override
  String get routeFallbackActive =>
      'Itinéraire non vérifié – suivez toujours la signalisation';

  @override
  String get routeOptionsTitle => 'Choisir un itinéraire';

  @override
  String get routeOptionRecommended => 'Recommandé';

  @override
  String get routeOptionRecommendedSubtitle =>
      'Vérifié selon les règles CruizX pour le véhicule sélectionné.';

  @override
  String get routeOptionAlternative => 'Itinéraire alternatif';

  @override
  String get routeOptionAlternativeSubtitle =>
      'Itinéraire légal — autres routes ou un peu plus long.';

  @override
  String get routeOptionUnverified => 'Itinéraire alternatif non vérifié';

  @override
  String routeOptionUnverifiedSubtitle(Object vehicleType) {
    return 'Impossible à vérifier entièrement pour votre $vehicleType. Vérifiez la signalisation avant de conduire.';
  }

  @override
  String get routeOptionChoose => 'Choisir';

  @override
  String routeOptionMetrics(Object km, Object minutes) {
    return '$km km · $minutes min';
  }

  @override
  String get routeOptionWarningFooter =>
      'CruizX n\'approuve jamais automatiquement les routes interdites. Respectez toujours la signalisation et les règles locales.';

  @override
  String get mapModeLabel2d => '2D';

  @override
  String get mapModeLabel3d => '3D';

  @override
  String mapManeuverInDistance(Object distance) {
    return 'Dans $distance';
  }

  @override
  String mapManeuverTowardRoad(Object road) {
    return 'Vers $road';
  }

  @override
  String get mapManeuverGenericCycleway => 'la piste cyclable';

  @override
  String get mapManeuverGenericFootway => 'la voie piétonne';

  @override
  String get mapManeuverGenericPath => 'le chemin';

  @override
  String get mapManeuverGenericRoad => 'la route';

  @override
  String get mapSimulateButton => 'Simuler';

  @override
  String get speedometerLiveSpeed => 'Vitesse actuelle';

  @override
  String speedometerMaxSpeedWithUnit(Object value, Object unit) {
    return 'Vitesse max : $value $unit';
  }

  @override
  String get speedometerSlowDown => 'Ralentissez.';

  @override
  String get reportAlertTitle => 'Signaler une alerte';

  @override
  String get reportAlertDescHint => 'Description (facultatif)';

  @override
  String get reportAlertSubmit => 'Envoyer l\'alerte';

  @override
  String reportAlertNearby(Object type, Object distance) {
    return '$type · $distance m devant';
  }

  @override
  String get alertTypeRoadClosure => 'Route barrée';

  @override
  String get alertTypePolice => 'Police';

  @override
  String get alertTypeRoadwork => 'Travaux';

  @override
  String get alertTypeAccident => 'Accident';

  @override
  String get alertTypeTrafficJam => 'Embouteillage';

  @override
  String get alertTypeSpeedCamera => 'Radar';

  @override
  String get alertTypeHazard => 'Danger';

  @override
  String get alertTypeNarrowRoad => 'Route étroite';

  @override
  String get alertTypeSteepHill => 'Pente raide';

  @override
  String get alertTypeSpeedBump => 'Ralentisseur haut';

  @override
  String get alertTypeMeetup => 'Point de rendez-vous';

  @override
  String get alertTypeParking => 'Parking';

  @override
  String get alertTypeFoodStop => 'Pause repas';

  @override
  String get alertTypeCharging => 'Recharge';

  @override
  String get alertTypeHangout => 'Lieu de rassemblement';

  @override
  String get alertGpsUnavailable => 'GPS pas encore disponible';

  @override
  String get alertMustBeLoggedIn => 'Vous devez être connecté pour signaler';

  @override
  String get alertsScreenSubtitle =>
      'Informations en direct de Trafikverket et des conducteurs CruizX dans un rayon de ~50 km. Confirmez les alertes communautaires avec le pouce.';

  @override
  String get alertReportButton => 'Signaler';

  @override
  String get alertTimeJustNow => 'À l\'instant';

  @override
  String alertTimeMinutes(Object n) {
    return 'il y a $n min';
  }

  @override
  String alertTimeHours(Object n) {
    return 'il y a $n h';
  }

  @override
  String get alertsEmptyTitle => 'Aucune alerte active à proximité';

  @override
  String get alertsEmptySubtitle =>
      'Vous voyez quelque chose sur la route ? Signalez-le !';

  @override
  String get alertReportQuestion => 'Que voyez-vous sur la route ?';

  @override
  String get alertReportDescHint2 =>
      'Description facultative… (ex. \"grosse branche\")';

  @override
  String get alertReportedSuccess => 'Alerte signalée ! Merci 🙏';

  @override
  String get alertReportFailed =>
      'Impossible de signaler l\'alerte pour le moment.';

  @override
  String get adBannerLoading => 'Chargement de la pub…';

  @override
  String get adBannerWaitingRetry =>
      'La pub attend le réseau… (appuyez pour réessayer)';

  @override
  String get mapStartNavigation => 'Démarrer la navigation';

  @override
  String get mapEndNavigation => 'Arrêter la navigation';

  @override
  String get convoyShowAll => 'Tout afficher';

  @override
  String get convoyYouBadge => 'Vous';

  @override
  String convoyShareCopied(Object name, Object code) {
    return 'Copié ! Partager : \"$name\" code : $code';
  }

  @override
  String convoyShareClipboard(Object name, Object code) {
    return 'Convoi CruizX : \"$name\" (code : $code)';
  }

  @override
  String convoyPinMarkedBy(Object name) {
    return 'Marqué par $name';
  }

  @override
  String get convoyNavigateToPin => 'Naviguer ici';

  @override
  String get convoyEtaArrived => 'Arrivé !';

  @override
  String convoyEtaMinutes(Object minutes, Object time) {
    return '$minutes min · $time';
  }

  @override
  String convoyEtaHours(Object hours, Object minutes, Object time) {
    return '${hours}h ${minutes}min · $time';
  }

  @override
  String get paywallTitle => 'Passer à CruizX Pro';

  @override
  String get paywallSubtitle => 'Sans limites. Sans pub. Accès complet.';

  @override
  String get paywallPrice => '3,49 € / mois';

  @override
  String get paywallUpgradeButton => 'Passer à Pro';

  @override
  String paywallLifetimeButton(Object price) {
    return 'Acheter Pro à vie · $price';
  }

  @override
  String get paywallRestoreButton => 'Restaurer l\'achat';

  @override
  String paywallDisclosure(Object price) {
    return 'CruizX Pro · $price/mois · renouvellement automatique. Annulez à tout moment dans Réglages au moins 24 heures avant le renouvellement. Facturé sur votre compte Apple ID.';
  }

  @override
  String paywallDisclosureAndroid(Object price) {
    return 'CruizX Pro · $price/mois · renouvellement automatique. Géré et facturé via Stripe. Annulez à tout moment sur cruizx.com ou contactez le support.';
  }

  @override
  String get paywallPriceOneTime => '249 kr';

  @override
  String paywallDisclosureOneTime(Object price) {
    return 'CruizX Pro · $price · achat unique. Débité une seule fois sur votre compte Apple ID. Aucun abonnement ni renouvellement.';
  }

  @override
  String get paywallFreeLabel => 'Free';

  @override
  String get paywallProLabel => 'Pro';

  @override
  String get paywallStartTrialButton => 'Commencer l\'essai gratuit de 7 jours';

  @override
  String paywallTrialNote(Object price) {
    return '7 jours gratuits, puis $price en achat unique.';
  }

  @override
  String get paywallFeatureRoutes => 'Itinéraires de navigation';

  @override
  String get paywallFreeRouteLimit => 'Illimité';

  @override
  String get paywallProRouteLimit => 'Illimité';

  @override
  String get paywallFeatureConvoy => 'Convoi';

  @override
  String get paywallFreeConvoyLimit => '1 actif, 2 membres';

  @override
  String get paywallProConvoyLimit => 'Illimité';

  @override
  String get paywallFeatureAds => 'Publicités';

  @override
  String get paywallFreeAds => 'Affichées';

  @override
  String get paywallProAds => 'Aucune';

  @override
  String get paywallRouteLimitTitle => 'Itinéraires illimités';

  @override
  String get paywallRouteLimitBody =>
      'Les itinéraires de navigation sont également illimités dans la version gratuite.';

  @override
  String get routeUpgradePromptTitle => 'Continuer sans publicité ?';

  @override
  String get routeUpgradePromptBody =>
      'Vous avez créé deux itinéraires aujourd’hui. La version gratuite offre des itinéraires illimités, tandis que Pro supprime les publicités et débloque davantage de fonctionnalités. Souhaitez-vous passer à Pro ?';

  @override
  String get paywallConvoyLimitTitle => 'Limite de convoi atteinte';

  @override
  String get paywallConvoyLimitBody =>
      'Les utilisateurs gratuits ne peuvent être que dans 1 convoi à la fois.';

  @override
  String get paywallMemberLimitTitle => 'Le convoi est complet';

  @override
  String get paywallMemberLimitBody =>
      'Les utilisateurs gratuits ne peuvent rejoindre que des convois de moins de 2 membres. Passez à Pro pour un accès illimité.';

  @override
  String get paywallPurchaseSuccess =>
      'Vous êtes maintenant un utilisateur Pro !';

  @override
  String get paywallPurchaseFailed =>
      'L\'achat n\'a pas pu être finalisé. Vérifiez votre compte App Store et réessayez.';

  @override
  String get paywallRestoreSuccess => 'Achat restauré !';

  @override
  String get paywallLoginRequiredTitle => 'Connexion requise';

  @override
  String get paywallLoginRequiredBody =>
      'Vous avez besoin d\'un compte pour acheter CruizX Pro. Créez un compte gratuit dans l\'application pour continuer.';

  @override
  String get paywallLoginRequiredAction => 'OK';

  @override
  String get paywallRestoreNotFound => 'Aucun achat précédent trouvé.';

  @override
  String get profileFreePlan => 'Plan gratuit';

  @override
  String get profileProPlan => 'Plan Pro';

  @override
  String get profileUpgradeToPro => 'Passer à Pro';

  @override
  String profileRoutesUsed(Object count) {
    return 'Itinéraires aujourd\'hui : $count';
  }

  @override
  String get profileChangePhoto => 'Changer la photo de profil';

  @override
  String get profileTakePhoto => 'Prendre une photo';

  @override
  String get profileChooseFromGallery => 'Choisir dans la galerie';

  @override
  String get profilePhotoUploadFailed => 'Échec du téléchargement de la photo';

  @override
  String get parentModeTitle => 'Mode parent';

  @override
  String get parentModeDescription =>
      'Permettez à un parent de suivre votre conduite en temps réel.';

  @override
  String get parentModeLoginRequired =>
      'Vous devez être connecté pour utiliser le mode parent.';

  @override
  String get parentModeEnable => 'Activer le mode parent';

  @override
  String get parentModeEnabledSubtitle =>
      'Les parents peuvent suivre votre conduite';

  @override
  String get parentModeDisabledSubtitle => 'Aucun partage actif';

  @override
  String get parentModeInviteCode => 'Code d\'invitation';

  @override
  String get parentModeInviteCodeSubtitle =>
      'Partagez ce code avec votre parent pour lier son compte.';

  @override
  String get parentModeCopyCode => 'Copier';

  @override
  String get parentModeShareCode => 'Partager';

  @override
  String get parentModeCodeCopied => 'Code copié !';

  @override
  String get parentModeShareSubject => 'Code parent CruizX';

  @override
  String parentModeShareMessage(Object code) {
    return 'Bonjour ! Utilisez ce code pour suivre ma conduite dans CruizX : $code';
  }

  @override
  String get parentModeLinkedParents => 'Parents liés';

  @override
  String get parentModeNoParentsLinked =>
      'Aucun parent lié. Partagez votre code !';

  @override
  String get parentModeUnlinkTitle => 'Supprimer le parent ?';

  @override
  String parentModeUnlinkMessage(Object name) {
    return 'Voulez-vous supprimer $name en tant que parent ? Il ne pourra plus suivre votre conduite.';
  }

  @override
  String get parentModeUnlink => 'Supprimer';

  @override
  String get parentModeShareSettings => 'Que partager';

  @override
  String get parentModeShareLocation => 'Partager la position';

  @override
  String get parentModeShareLocationSubtitle =>
      'Montrer où vous êtes sur la carte';

  @override
  String get parentModeShareSpeed => 'Partager la vitesse';

  @override
  String get parentModeShareSpeedSubtitle => 'Montrer votre vitesse actuelle';

  @override
  String get parentModeAlertSettings => 'Notifications aux parents';

  @override
  String get parentModeSpeedAlert => 'Alerte de vitesse';

  @override
  String parentModeSpeedAlertSubtitle(Object limit) {
    return 'Notifier quand la vitesse dépasse $limit km/h';
  }

  @override
  String get parentModeSpeedLimit => 'Limite';

  @override
  String get parentModeNightAlert => 'Alerte conduite nocturne';

  @override
  String parentModeNightAlertSubtitle(Object start, Object end) {
    return 'Notifier en cas de conduite entre $start–$end';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get login => 'Se connecter';

  @override
  String get parentDashboardTitle => 'Tableau de bord parent';

  @override
  String get parentDashboardMapTab => 'Carte';

  @override
  String get parentDashboardAlertsTab => 'Alertes';

  @override
  String get parentDashboardAddChild => 'Ajouter un enfant';

  @override
  String get parentDashboardOnline => 'En ligne';

  @override
  String get parentDashboardOffline => 'Hors ligne';

  @override
  String get parentDashboardNoAlerts =>
      'Aucune alerte dans les dernières 24 heures';

  @override
  String get parentDashboardNoChildren => 'Aucun enfant lié';

  @override
  String get parentDashboardNoChildrenHint =>
      'Ajoutez un enfant en entrant son code d\'invitation du mode parent CruizX.';

  @override
  String get parentDashboardEnterCode => 'Entrer le code d\'invitation';

  @override
  String get parentDashboardEnterCodeHint =>
      'Demandez à votre enfant de partager son code d\'invitation à 6 caractères depuis les paramètres du mode parent.';

  @override
  String get parentDashboardLink => 'Lier';

  @override
  String get parentDashboardLinkSuccess => 'Liaison réussie !';

  @override
  String get parentDashboardLinkFailed =>
      'Impossible de trouver un enfant avec ce code. Vérifiez le code et réessayez.';

  @override
  String get parentDashboardLinkSelf =>
      'Vous ne pouvez pas lier votre propre compte. Demandez à votre enfant de partager son code depuis son compte.';

  @override
  String get parentDashboardSpeedingAlert => 'Alerte de vitesse';

  @override
  String parentDashboardSpeedingDetail(
    Object name,
    Object speed,
    Object limit,
  ) {
    return '$name a roulé à $speed km/h (limite : $limit km/h)';
  }

  @override
  String get parentDashboardNightAlert => 'Conduite nocturne';

  @override
  String parentDashboardNightDetail(Object name) {
    return '$name conduit la nuit';
  }

  @override
  String get parentDashboardViewChild => 'Voir en tant que parent';

  @override
  String get settingsVoiceNavigation => 'Navigation vocale';

  @override
  String get settingsVoiceNavigationSubtitle =>
      'Lire les instructions de virage à voix haute';

  @override
  String get voiceTurnLeft => 'Tournez à gauche';

  @override
  String get voiceTurnRight => 'Tournez à droite';

  @override
  String get voiceTurnSharpLeft => 'Tournez fortement à gauche';

  @override
  String get voiceTurnSharpRight => 'Tournez fortement à droite';

  @override
  String get voiceTurnSlightLeft => 'Tournez légèrement à gauche';

  @override
  String get voiceTurnSlightRight => 'Tournez légèrement à droite';

  @override
  String get voiceContinue => 'Continuez tout droit';

  @override
  String get voiceRoundabout => 'Entrez dans le rond-point';

  @override
  String get voiceDestination => 'Vous êtes arrivé à destination';

  @override
  String voiceInMeters(Object meters) {
    return 'Dans $meters mètres';
  }

  @override
  String voiceInKm(Object km) {
    return 'Dans $km kilomètres';
  }

  @override
  String get mfaSetupTitle => 'Activer l\'authentification à deux facteurs';

  @override
  String get mfaSetupSubtitle =>
      'Scannez le QR code avec une application d\'authentification comme Google Authenticator ou Authy';

  @override
  String get mfaScanQr =>
      'Scannez le code ci-dessus et entrez le code à 6 chiffres ci-dessous';

  @override
  String get mfaVerifyButton => 'Vérifier';

  @override
  String get mfaVerifyTitle => 'Authentification à deux facteurs';

  @override
  String get mfaVerifySubtitle =>
      'Entrez le code à 6 chiffres de votre application d\'authentification';

  @override
  String get mfaInvalidCode => 'Code invalide, réessayez';

  @override
  String get mfaCancel => 'Annuler et se déconnecter';

  @override
  String get mfaProfileTitle => 'Authentification à deux facteurs';

  @override
  String get mfaStatusOn => 'Activée — votre compte est protégé';

  @override
  String get mfaStatusOff => 'Désactivée';

  @override
  String get mfaTurnOn => 'Activer';

  @override
  String get mfaTurnOff => 'Désactiver';

  @override
  String get mfaDisableTitle => 'Désactiver la 2FA ?';

  @override
  String get mfaDisableBody =>
      'Votre compte sera moins sécurisé sans l\'authentification à deux facteurs.';

  @override
  String get mfaDisableConfirm => 'Désactiver';

  @override
  String get mfaShowManualKey =>
      'Impossible de scanner ? Afficher la clé manuellement';

  @override
  String get mfaHideManualKey => 'Masquer la clé manuelle';

  @override
  String get mfaKeyCopied => 'Clé copiée';

  @override
  String get mfaRecommendTitle => 'Protégez votre compte';

  @override
  String get mfaRecommendBody =>
      'Nous vous recommandons d\'activer l\'authentification à deux facteurs pour protéger votre compte. Vous pouvez utiliser une application comme Google Authenticator ou Authy.';

  @override
  String get mfaRecommendSetup => 'Activer maintenant';

  @override
  String get mfaRecommendLater => 'Plus tard';

  @override
  String get favHome => 'Domicile';

  @override
  String get favSchool => 'École';

  @override
  String get favWork => 'Travail';

  @override
  String get favAddTitle => 'Enregistrer le lieu';

  @override
  String get favLabelHint => 'Nom (ex. Ami)';

  @override
  String get favSaved => 'Lieu enregistré';

  @override
  String get favDeleted => 'Lieu supprimé';

  @override
  String favDeleteConfirm(Object name) {
    return 'Supprimer $name ?';
  }

  @override
  String favSetAs(Object type) {
    return 'Enregistrer comme $type';
  }

  @override
  String get favCustom => 'Autre favori';

  @override
  String get ttsVoiceHint =>
      'Astuce : Téléchargez de meilleures voix dans Réglages → Accessibilité → Contenu énoncé → Voix';

  @override
  String get ttsVoiceHintDismiss => 'OK';

  @override
  String get settingsVectorMap => 'Carte vectorielle';

  @override
  String get settingsVectorMapOn =>
      'Rendu net à tous les niveaux de zoom, zoom fluide';

  @override
  String get settingsVectorMapOff =>
      'Standard — rapide et mis en cache hors ligne';

  @override
  String get publicGatheringStartTime => 'Heure de début';

  @override
  String get publicGatheringEndTime => 'Heure de fin';

  @override
  String get publicGatheringScheduleInvalid =>
      'L’heure de fin doit être postérieure à l’heure de début.';

  @override
  String get publicGatheringEndAction => 'Terminer le rassemblement';

  @override
  String get publicGatheringDeleteAction => 'Supprimer le rassemblement';

  @override
  String get publicGatheringEndConfirm =>
      'Terminer le rassemblement maintenant ? Les participants ne pourront plus le trouver.';

  @override
  String get publicGatheringDeleteConfirm =>
      'Supprimer définitivement ce rassemblement ? Cette action est irréversible.';

  @override
  String get publicGatheringReportAction => 'Signaler le rassemblement';

  @override
  String get publicGatheringBlockAction => 'Bloquer le rassemblement';

  @override
  String get publicGatheringReportParticipant => 'Signaler le participant';

  @override
  String get publicGatheringBlockParticipant => 'Bloquer le participant';

  @override
  String get publicGatheringReportReason => 'Que souhaitez-vous signaler ?';

  @override
  String get publicGatheringReportSent => 'Votre signalement a été envoyé.';

  @override
  String get publicGatheringBlocked =>
      'Le contenu bloqué ne sera plus affiché.';

  @override
  String get reportReasonInappropriate => 'Contenu inapproprié';

  @override
  String get reportReasonHarassment => 'Harcèlement';

  @override
  String get reportReasonDangerous => 'Comportement dangereux';

  @override
  String get reportReasonSpam => 'Spam ou trompeur';

  @override
  String get reportReasonOther => 'Autre';

  @override
  String get publicGatheringNearbyNotifications =>
      'Notifications de rassemblements à proximité';

  @override
  String get publicGatheringNearbyNotificationsSubtitle =>
      'Me prévenir une fois lorsqu’un rassemblement public à moins de 25 km commence dans les 24 heures.';

  @override
  String get publicGatheringUpcoming => 'À venir';

  @override
  String get publicGatheringStarted => 'En cours';

  @override
  String get aiRouteButton => 'Vérifier avec l’IA';

  @override
  String get aiRouteTitle => 'Analyse d’itinéraire CruizX IA';

  @override
  String get aiConsentTitle => 'Utiliser l’analyse IA de l’itinéraire ?';

  @override
  String get aiConsentBody =>
      'CruizX utilise des données comme la distance, la durée, le type de véhicule, les noms de routes et le nombre d’alertes pour analyser l’itinéraire. Votre position exacte, les coordonnées de destination et votre identité ne sont pas partagées. L’analyse peut contenir des erreurs et ne modifie jamais votre itinéraire.';

  @override
  String get aiConsentAccept => 'Accepter et continuer';

  @override
  String get aiConsentDecline => 'Pas maintenant';

  @override
  String get aiSignInRequired => 'Connectez-vous pour utiliser l’analyse IA.';

  @override
  String get aiLoading => 'Vérification de l’itinéraire…';

  @override
  String get aiUnavailable =>
      'L’analyse IA est indisponible pour le moment. Votre itinéraire reste inchangé.';

  @override
  String get aiDailyLimit =>
      'Vous avez atteint la limite quotidienne d’analyses IA.';

  @override
  String get aiHighlights => 'Points positifs';

  @override
  String get aiCautions => 'Points à vérifier';

  @override
  String get aiRecommendation => 'Recommandation';

  @override
  String get aiDisclaimer =>
      'Résumé IA fondé uniquement sur les données disponibles. Respectez la signalisation et les conditions routières actuelles.';

  @override
  String get aiReport => 'Signaler la réponse';

  @override
  String get aiReportTitle => 'Pourquoi signalez-vous cette réponse ?';

  @override
  String get aiReportIncorrect => 'Information incorrecte';

  @override
  String get aiReportUnsafe => 'Conseil dangereux';

  @override
  String get aiReportInappropriate => 'Contenu inapproprié';

  @override
  String get aiReportOther => 'Autre problème';

  @override
  String get aiReportSent => 'Merci. La réponse IA a été signalée.';
}
