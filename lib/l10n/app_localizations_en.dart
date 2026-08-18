// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CruizX';

  @override
  String get navMap => 'Map';

  @override
  String get navAlerts => 'Alerts';

  @override
  String get navConvoy => 'Convoy';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSettings => 'Settings';

  @override
  String get splashPreparingStartup => 'Preparing startup...';

  @override
  String get splashLoadingCoreModules => 'Loading core modules...';

  @override
  String get splashInitializingAccountSession =>
      'Initializing account session...';

  @override
  String get splashLoadingPreferences => 'Loading preferences...';

  @override
  String get splashFinalizingStartup => 'Finalizing startup...';

  @override
  String get splashReady => 'Ready';

  @override
  String get splashVersionLine => 'v1.2.0 | CruizX by KimTechTool';

  @override
  String get a11yCenterOnLocation => 'Center the map on my location';

  @override
  String get a11yStopFollowingLocation => 'Stop following my location';

  @override
  String get a11ySwitchTo2d => 'Switch to 2D map';

  @override
  String get a11ySwitchTo3d => 'Switch to 3D map';

  @override
  String get a11yUseDarkMap => 'Use dark map';

  @override
  String get a11yUseLightMap => 'Use light map';

  @override
  String get a11yEnableVoiceNavigation => 'Turn on voice navigation';

  @override
  String get a11yDisableVoiceNavigation => 'Turn off voice navigation';

  @override
  String get a11yDismissAlert => 'Dismiss the alert';

  @override
  String get a11yClearSearch => 'Clear the search';

  @override
  String get a11yOpenSearch => 'Open address search';

  @override
  String get a11yAddFavorite => 'Add favorite place';

  @override
  String get a11yConfirmAlert => 'Confirm the alert';

  @override
  String get alertsTitle => 'Community Alerts';

  @override
  String get alertsSubtitle =>
      'Report and view road hazards, checks, and road conditions.';

  @override
  String get convoyRequiresSignInTitle => 'Convoy requires sign in';

  @override
  String get convoyRequiresSignInSubtitle =>
      'Sign in or create an account here to create convoy groups and see live locations.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signInEmailDialogTitle => 'Sign in with email OTP';

  @override
  String get signUpEmailDialogTitle => 'Create account with email OTP';

  @override
  String get signInEmailFieldLabel => 'Email';

  @override
  String get signInEmailHint => 'name@example.com';

  @override
  String get signInSendOtp => 'Send code';

  @override
  String get signUpSendOtp => 'Send account code';

  @override
  String get signInOtpFieldLabel => 'OTP code';

  @override
  String get signInOtpHint => '6-digit code';

  @override
  String get signInVerifyOtp => 'Verify code';

  @override
  String get signInOtpSent => 'OTP code sent to your email.';

  @override
  String get signUpOtpSent => 'Account creation code sent to your email.';

  @override
  String get signInOtpInvalid =>
      'Could not verify OTP. Check your code and try again.';

  @override
  String get signUpNoAccountAction => 'No account? Create one';

  @override
  String get signUpHaveAccountAction => 'Already have an account? Sign in';

  @override
  String get authGenericError => 'Something went wrong. Please try again.';

  @override
  String get authWelcomeBack => 'Welcome back to CruizX';

  @override
  String get authRegisterSubtitle => 'Join the CruizX community';

  @override
  String get authEmailLabel => 'Email address';

  @override
  String get authEmailRequired => 'Enter your email address';

  @override
  String get authEmailInvalid => 'Invalid email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String get authPasswordMinLength =>
      'At least 6 characters, a number and a special character';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authConfirmPasswordRequired => 'Confirm your password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get authDisplayNameLabel => 'Display name';

  @override
  String get authDisplayNameRequired => 'Enter your name';

  @override
  String get authNoAccountPrompt => 'No account? ';

  @override
  String get authAlreadyHaveAccountPrompt => 'Already have an account? ';

  @override
  String get authCancel => 'Cancel';

  @override
  String get authForgotPasswordLink => 'Forgot password?';

  @override
  String get authForgotPasswordTitle => 'Reset password';

  @override
  String get authForgotPasswordDescription =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get authForgotPasswordButton => 'Send reset link';

  @override
  String get authForgotPasswordSuccess =>
      'If the account exists, we\'ve sent a reset link to your email.';

  @override
  String get authResetPasswordTitle => 'New password';

  @override
  String get authResetPasswordDescription => 'Enter your new password below.';

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String get authResetPasswordButton => 'Save password';

  @override
  String get authResetPasswordSuccess => 'Your password has been changed.';

  @override
  String get authErrorAllFieldsRequired => 'All fields are required.';

  @override
  String get authErrorPasswordTooShort =>
      'Password must be at least 6 characters and include a number and a special character.';

  @override
  String get authErrorConfirmEmail =>
      'Check your email to confirm your account, then sign in.';

  @override
  String get authEmailConfirmedTitle => 'Email confirmed';

  @override
  String get authEmailConfirmedBody =>
      'Your email address has been confirmed. You are now signed in.';

  @override
  String get authErrorEmailAndPasswordRequired =>
      'Enter your email and password.';

  @override
  String get authErrorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get authErrorEmailAlreadyInUse =>
      'An account with that email already exists.';

  @override
  String get authErrorInvalidEmail =>
      'The email address is invalid. Check it and try again.';

  @override
  String get authErrorRateLimited =>
      'Too many attempts in a short time. Wait a moment and try again.';

  @override
  String get authErrorSignUpDisabled =>
      'New accounts cannot be created right now. Contact CruizX Support.';

  @override
  String get authErrorEmailDeliveryFailed =>
      'The confirmation email could not be sent. Please try again shortly.';

  @override
  String get authErrorNetworkUnavailable =>
      'Could not connect to the account service. Check your internet connection and try again.';

  @override
  String get convoyRealtimeBackendMissing =>
      'Realtime convoy is not configured yet. Add backend config to share live positions between users.';

  @override
  String get convoyModeTitle => 'Convoy Mode';

  @override
  String get convoyModeSubtitle =>
      'Create group driving with a shared destination and live locations.';

  @override
  String get convoyCreateButton => 'Create convoy';

  @override
  String get publicGatheringsTitle => 'Public meetups';

  @override
  String get publicGatheringsSubtitle =>
      'Find a meetup spot, join publicly, and choose whether to show your live location.';

  @override
  String get publicGatheringsMineTab => 'Mine';

  @override
  String get publicGatheringsPublicTab => 'Public';

  @override
  String get publicGatheringsEmpty =>
      'There are no active public meetups right now.';

  @override
  String get publicGatheringCreateButton => 'Create public meetup';

  @override
  String get publicGatheringCreateTitle => 'New public meetup';

  @override
  String get publicGatheringPlaceHint => 'Meetup spot, e.g. the town square';

  @override
  String get publicGatheringLocationExplanation =>
      'The meetup is placed at your current position and stays active for 6 hours. Live location is optional for every participant.';

  @override
  String get publicGatheringLocationRequired =>
      'Location access is required to set the meetup spot.';

  @override
  String get publicGatheringPublish => 'Publish';

  @override
  String get publicGatheringStartSharing => 'Share my live location';

  @override
  String get publicGatheringStopSharing => 'Stop sharing my live location';

  @override
  String get convoyOpenButton => 'Open';

  @override
  String get convoyJoinButton => 'Join';

  @override
  String get convoyLeaveButton => 'Leave';

  @override
  String get convoyJoinFirstHint =>
      'Join the convoy first, then tap it to open chat and map.';

  @override
  String get convoyJoinByCodeTitle => 'Join convoy';

  @override
  String get convoyJoinByCodeHint => 'Enter the convoy code you received';

  @override
  String get convoyJoinWithCodeButton => 'Join';

  @override
  String get convoyJoinByCodeNotFound => 'No convoy found with that code.';

  @override
  String convoyJoinByCodeSuccess(String name) {
    return 'You joined $name!';
  }

  @override
  String get convoyInviteButton => 'Invite';

  @override
  String get convoyTabMap => 'Map';

  @override
  String get convoyTabChat => 'Chat';

  @override
  String get convoyMapHint => 'Tap map to place a shared pin.';

  @override
  String get convoyRecenterTooltip => 'Recenter and follow my position';

  @override
  String get convoyPinDialogTitle => 'Add map pin';

  @override
  String get convoyPinLabel => 'Pin label';

  @override
  String get convoyPinHint => 'e.g. Meet here';

  @override
  String get convoyPinAdd => 'Add pin';

  @override
  String get convoyHazardPolice => 'Police';

  @override
  String get convoyHazardRoadwork => 'Roadwork';

  @override
  String get convoyHazardAccident => 'Accident';

  @override
  String get convoyHazardTrafficJam => 'Traffic jam';

  @override
  String get convoyHazardSpeedCamera => 'Speed camera';

  @override
  String get convoyHazardCustom => 'Custom pin';

  @override
  String get convoyPoiMeetup => 'Meetup spot';

  @override
  String get convoyPoiMeetupSubtitle =>
      'Mark a clear place where the convoy should gather';

  @override
  String get convoyPoiParking => 'Parking';

  @override
  String get convoyPoiFoodStop => 'Food stop';

  @override
  String get convoyPoiCharging => 'Charging';

  @override
  String get routeStopFuel => 'Fuel';

  @override
  String get routeStopCafe => 'Café';

  @override
  String get routeStopGrocery => 'Grocery';

  @override
  String get convoyPoiHangout => 'Hangout spot';

  @override
  String get convoyChatEmpty => 'No messages yet.';

  @override
  String get convoyChatPlaceholder => 'Write a message...';

  @override
  String get convoyChatSend => 'Send';

  @override
  String get convoyNameDialogTitle => 'Create convoy';

  @override
  String get convoyNameFieldLabel => 'Convoy name';

  @override
  String get convoyNameHint => 'e.g. Friday Night Ride';

  @override
  String get convoyCreateConfirm => 'Create';

  @override
  String get convoyCreateCancel => 'Cancel';

  @override
  String get convoyListEmpty => 'No convoys yet. Create the first one.';

  @override
  String get convoyListEmptyMine => 'You have not joined any convoys yet.';

  @override
  String get convoyFilterAll => 'All';

  @override
  String get convoyFilterMine => 'Mine';

  @override
  String convoyMembers(Object count) {
    return '$count members';
  }

  @override
  String get convoyMemberMe => 'Me';

  @override
  String convoyMemberStaleTime(Object mins) {
    return '${mins}m ago';
  }

  @override
  String convoyCreatedBy(Object leader) {
    return 'Created by $leader';
  }

  @override
  String get profileTitle => 'Profile & Stats';

  @override
  String get profileNotSignedIn => 'You are not signed in.';

  @override
  String get profileSignInInConvoyHint =>
      'Sign in is available in the Convoy tab.';

  @override
  String profileSignedInAs(Object name) {
    return 'Signed in as: $name';
  }

  @override
  String get profileDefaultName => 'CruizX Driver';

  @override
  String get profileSignedIn => 'Signed in';

  @override
  String get profileStatsTitle => 'Statistics';

  @override
  String get profileStatsConvoys => 'Convoys driven';

  @override
  String get profileStatsTotalDistance => 'Total distance';

  @override
  String get profileStatsSpeedViolations => 'Speed violations';

  @override
  String get profileVehicleTitle => 'My vehicle';

  @override
  String get profileVehicleElectric => 'Electric vehicle';

  @override
  String get profileVehicleElectricSubtitle =>
      'Show charging stations on the map';

  @override
  String get profileVehicleStuddedTires => 'Studded tires';

  @override
  String get profileVehicleStuddedTiresSubtitle =>
      'Avoid streets with studded tire bans';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageSwedish => 'Swedish';

  @override
  String get settingsLanguageFrench => 'French';

  @override
  String get settingsLanguageNorwegian => 'Norwegian';

  @override
  String get settingsLanguageDanish => 'Danish';

  @override
  String get settingsLanguageFinnish => 'Finnish';

  @override
  String get settingsLanguageSpanish => 'Spanish';

  @override
  String get settingsLanguageItalian => 'Italian';

  @override
  String get settingsCountryLabel => 'Country (traffic rules)';

  @override
  String get settingsCountrySweden => '🇸🇪 Sweden';

  @override
  String get settingsCountryNorway => '🇳🇴 Norway';

  @override
  String get settingsCountryDenmark => '🇩🇰 Denmark';

  @override
  String get settingsCountryFinland => '🇫🇮 Finland';

  @override
  String get settingsCountryFrance => '🇫🇷 France';

  @override
  String get settingsCountrySpain => '🇪🇸 Spain';

  @override
  String get settingsCountryItaly => '🇮🇹 Italy';

  @override
  String get settingsCountryUnitedKingdom => '🇬🇧 United Kingdom';

  @override
  String get settingsCountryHint =>
      'Speed limits and road rules adapt to the selected country.';

  @override
  String settingsLanguageCurrentlyUsing(Object mode) {
    return 'Currently using: $mode';
  }

  @override
  String get settingsVehicleTypeLabel => 'Vehicle type';

  @override
  String get settingsVehicleAtractor => 'A-tractor';

  @override
  String get settingsVehicleLowVehicle => 'Low vehicle';

  @override
  String get settingsVehicleMopedCar => 'Moped car';

  @override
  String get settingsVehicleMopedClassI => 'Class I moped';

  @override
  String get settingsVehicleMopedClassII => 'Class II moped (25 km/h)';

  @override
  String get settingsVehicleElectricScooter => 'Electric scooter';

  @override
  String get settingsElectricScooterLegalNotice =>
      'Only use a road-legal electric scooter where local rules permit it. Signs, municipal rules and rental zones always take priority over the route.';

  @override
  String get settingsEscooterRentalOnlyNotice =>
      'In the UK, only approved rental e-scooters are legal on public roads. Private e-scooters may only be used on private land with the landowner’s permission.';

  @override
  String get settingsVehicleTractor => 'Tractor';

  @override
  String get settingsVehicleCar => 'Car';

  @override
  String get settingsSpeedUnitKmh => 'km/h';

  @override
  String get settingsSpeedUnitMph => 'mph';

  @override
  String settingsMaxSpeedWithUnit(Object value, Object unit) {
    return 'Max speed: $value $unit';
  }

  @override
  String get settingsProCardTitle => 'CruizX Pro';

  @override
  String get settingsProStatusActive => 'Active';

  @override
  String get settingsProStatusInactive => 'Not active';

  @override
  String get settingsProDescriptionActive =>
      'You have access to all Pro features.';

  @override
  String get settingsProDescriptionInactive =>
      'Unlock all features with CruizX Pro.';

  @override
  String get settingsProFeatureRoutes => 'More AI route analyses';

  @override
  String get settingsProFeatureConvoy => 'Unlimited convoy members';

  @override
  String get settingsProFeatureAds => 'No ads';

  @override
  String get settingsProFeatureSupport => 'Priority support';

  @override
  String get settingsProSubscriptionNote =>
      'Subscription: CruizX Pro Monthly (1 month). Payment is charged to your Apple ID and renews automatically unless canceled at least 24 hours before the end of the current period.';

  @override
  String settingsProPricePerMonth(Object price) {
    return '$price / month';
  }

  @override
  String settingsProPriceOneTime(Object price) {
    return '$price';
  }

  @override
  String get settingsProOneTimeNote =>
      'One-time purchase: CruizX Pro (lifetime). Payment is charged once through the app store. No subscription and no auto-renewal.';

  @override
  String get settingsPrivacyPolicyLabel => 'Privacy Policy';

  @override
  String get settingsTermsOfUseLabel => 'Terms of Use (EULA)';

  @override
  String get settingsSupportLabel => 'Support';

  @override
  String get supportChatTitle => 'Live support chat';

  @override
  String get supportChatReplyTime => 'Replies within 24 hours';

  @override
  String get supportChatWelcome =>
      'Hi! How can we help you with CruizX? Send your message here and we will get back to you as soon as we can.';

  @override
  String get supportChatGuestNotice =>
      'You are chatting as a guest. This conversation is stored privately on this device.';

  @override
  String get supportChatLoginRequired =>
      'Sign in to start a private support chat and view your previous messages.';

  @override
  String get supportChatLoginAction => 'Sign in';

  @override
  String get supportChatMessageHint => 'Write a message…';

  @override
  String get supportChatSend => 'Send message';

  @override
  String get supportChatSendFailed =>
      'The message could not be sent. Please try again.';

  @override
  String get supportChatUnavailable =>
      'Support chat is currently unavailable. Please try again later.';

  @override
  String get supportChatTeam => 'CruizX Support';

  @override
  String get supportChatYou => 'You';

  @override
  String get supportAssistantTitle => 'CruizX Help Assistant';

  @override
  String get supportAssistantIntro =>
      'Get an instant answer from CruizX\'s prepared help guide, even without internet.';

  @override
  String get supportAssistantSuggestions => 'Common questions';

  @override
  String get supportAssistantNoMatch =>
      'I could not find a reliable prepared answer. You can forward the question to CruizX Support.';

  @override
  String get supportAssistantContact => 'Send to support';

  @override
  String get supportAssistantForwarded =>
      'The question was sent to CruizX Support.';

  @override
  String get supportAssistantHumanUnavailable =>
      'Prepared answers work offline, but human support requires internet.';

  @override
  String get settingsLinkOpenFailed => 'Could not open the link right now.';

  @override
  String get settingsRestorePurchaseFailed => 'Could not restore purchase.';

  @override
  String get settingsMapMarkerLabel => 'Map marker';

  @override
  String get settingsMapMarkerCategoryClassic => 'Classic';

  @override
  String get settingsMapMarkerCategoryMicrocar => 'Moped car';

  @override
  String get settingsMapMarkerCategoryEpa => 'EPA';

  @override
  String get settingsMapMarkerCategoryLigier => 'Ligier';

  @override
  String get settingsMapMarkerCategoryAixam => 'Aixam';

  @override
  String get settingsMapMarkerCategoryPickup => 'Pickup';

  @override
  String get settingsMapMarkerCategoryAtractor => 'A-tractor';

  @override
  String get settingsMapMarkerCategoryTractor => 'Tractor';

  @override
  String get settingsMapMarkerArrow => 'Arrow';

  @override
  String get settingsMapMarkerCompass => 'Compass';

  @override
  String get settingsMapMarkerTriangle => 'Triangle';

  @override
  String get settingsMapMarkerDot => 'Dot';

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
  String get settingsMapMarkerMopeds => 'Mopeds';

  @override
  String get settingsMapMarkerScooter => 'Scooter';

  @override
  String get settingsMapMarkerCrossMoped => 'Cross moped';

  @override
  String get settingsMapMarkerTractor => 'Traktor';

  @override
  String get settingsColorRed => 'Red';

  @override
  String get settingsColorBlue => 'Blue';

  @override
  String get settingsColorBlack => 'Black';

  @override
  String get settingsColorWhite => 'White';

  @override
  String get settingsColorGold => 'Gold';

  @override
  String get settingsColorSilver => 'Silver';

  @override
  String get settingsColorGreen => 'Green';

  @override
  String get settingsColorGraphite => 'Graphite';

  @override
  String get settingsColorYellow => 'Yellow';

  @override
  String get settingsColorOrange => 'Orange';

  @override
  String get settingsColorPink => 'Pink';

  @override
  String get navigationTitle => 'Turn-by-Turn Navigation';

  @override
  String get navigationSubtitle =>
      'Directions, next turn, and ETA optimized for slow vehicles.';

  @override
  String get mapStartingGps => 'Starting GPS...';

  @override
  String get mapTapToSelectDestination => 'Tap the map to select a destination';

  @override
  String get mapAddressFieldHint =>
      'Search address (e.g. Main St 10, Stockholm)';

  @override
  String get mapSearchingAddress => 'Searching address...';

  @override
  String get mapAddressNotFound => 'No address found. Try again.';

  @override
  String get mapAddressLookupFailed => 'Could not search address right now';

  @override
  String get mapLocationServicesDisabled => 'Location services are disabled';

  @override
  String get mapLocationPermissionMissing => 'Location permission is missing';

  @override
  String get mapGpsActive => 'GPS active';

  @override
  String get mapGpsUnavailable => 'GPS is unavailable in this environment';

  @override
  String get mapWaitingForGps =>
      'Waiting for GPS position before route calculation';

  @override
  String get mapCalculatingRoute => 'Calculating route...';

  @override
  String mapRouteReady(Object distance, Object minutes) {
    return 'Route ready: $distance km • $minutes min';
  }

  @override
  String get mapRouteFailed => 'Could not create route right now';

  @override
  String get mapRemaining => 'left';

  @override
  String get mapRouteNoRouteFound => 'No route found between selected points';

  @override
  String get mapRouteProviderUnavailable =>
      'Routing service is unavailable right now';

  @override
  String get mapRouteMissingApiKey =>
      'Routing is not configured on backend (missing API key)';

  @override
  String get mapRouteInvalidGeometry => 'Route data from server is invalid';

  @override
  String get mapRouteUnknownProvider =>
      'Routing provider is not configured correctly';

  @override
  String get mapRouteTooFastForVehicle =>
      'Route rejected: estimated average speed is too high for this vehicle type.';

  @override
  String get mapRouteNotAllowedForVehicle =>
      'No legally compliant route found for this vehicle type.';

  @override
  String get routeStopSheetSubtitle => 'Nearest stops along your current route';

  @override
  String get routeStopNearbySubtitle => 'Nearest options around you';

  @override
  String get routeStopEmpty => 'No good stops near the route right now.';

  @override
  String get routeStopNearbyEmpty => 'No good options near you right now.';

  @override
  String get searchSaved => 'Saved';

  @override
  String get searchRecent => 'Recent';

  @override
  String get searchNew => 'New';

  @override
  String routeStopFromRoute(Object distance) {
    return '$distance from route';
  }

  @override
  String routeStopAway(Object distance) {
    return '$distance away';
  }

  @override
  String get routeBlockedTitle => 'Route not available';

  @override
  String routeBlockedBody(Object vehicleType) {
    return 'No legal route was found to this destination for your $vehicleType. The destination may be on or only reachable via roads that are not allowed for this vehicle type (e.g. motorways).';
  }

  @override
  String get routeBlockedOk => 'OK';

  @override
  String get routeBlockedTryOther => 'Try a different destination';

  @override
  String get routeFallbackTitle => 'Unverified route found';

  @override
  String routeFallbackBody(Object vehicleType) {
    return 'We found a possible route, but it could not be fully verified for your $vehicleType. It may include roads that need checking. Always follow signs and local rules.';
  }

  @override
  String get routeFallbackCancel => 'Cancel';

  @override
  String get routeFallbackUse => 'Show anyway';

  @override
  String get routeFallbackActive => 'Unverified route – always follow signs';

  @override
  String get routeOptionsTitle => 'Choose route';

  @override
  String get routeOptionRecommended => 'Recommended';

  @override
  String get routeOptionRecommendedSubtitle =>
      'Verified by CruizX rules for the selected vehicle.';

  @override
  String get routeOptionAlternative => 'Alternative route';

  @override
  String get routeOptionAlternativeSubtitle =>
      'Legal route — different roads or slightly longer.';

  @override
  String get routeOptionUnverified => 'Unverified alternative route';

  @override
  String routeOptionUnverifiedSubtitle(Object vehicleType) {
    return 'Cannot be fully verified for your $vehicleType. Check signs before driving.';
  }

  @override
  String get routeOptionChoose => 'Choose';

  @override
  String routeOptionMetrics(Object km, Object minutes) {
    return '$km km · $minutes min';
  }

  @override
  String get routeOptionWarningFooter =>
      'CruizX never automatically approves restricted roads. Always follow signs and local rules.';

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
    return 'Toward $road';
  }

  @override
  String get mapManeuverGenericCycleway => 'the cycleway';

  @override
  String get mapManeuverGenericFootway => 'the footway';

  @override
  String get mapManeuverGenericPath => 'the path';

  @override
  String get mapManeuverGenericRoad => 'the road';

  @override
  String get mapSimulateButton => 'Simulate';

  @override
  String get speedometerLiveSpeed => 'Live speed';

  @override
  String speedometerMaxSpeedWithUnit(Object value, Object unit) {
    return 'Max speed: $value $unit';
  }

  @override
  String get speedometerSlowDown => 'Slow down.';

  @override
  String get reportAlertTitle => 'Report alert';

  @override
  String get reportAlertDescHint => 'Description (optional)';

  @override
  String get reportAlertSubmit => 'Submit alert';

  @override
  String reportAlertNearby(Object type, Object distance) {
    return '$type · $distance m ahead';
  }

  @override
  String get alertTypeRoadClosure => 'Road closure';

  @override
  String get alertTypePolice => 'Police';

  @override
  String get alertTypeRoadwork => 'Roadwork';

  @override
  String get alertTypeAccident => 'Accident';

  @override
  String get alertTypeTrafficJam => 'Traffic jam';

  @override
  String get alertTypeSpeedCamera => 'Speed camera';

  @override
  String get alertTypeHazard => 'Hazard';

  @override
  String get alertTypeNarrowRoad => 'Narrow road';

  @override
  String get alertTypeSteepHill => 'Steep hill';

  @override
  String get alertTypeSpeedBump => 'High speed bump';

  @override
  String get alertTypeMeetup => 'Meetup spot';

  @override
  String get alertTypeParking => 'Parking';

  @override
  String get alertTypeFoodStop => 'Food stop';

  @override
  String get alertTypeCharging => 'Charging';

  @override
  String get alertTypeHangout => 'Hangout spot';

  @override
  String get alertGpsUnavailable => 'GPS not available yet';

  @override
  String get alertMustBeLoggedIn => 'You must be signed in to report';

  @override
  String get alertsScreenSubtitle =>
      'Live information from Trafikverket and CruizX drivers within ~50 km. Tap the thumb to confirm community alerts.';

  @override
  String get alertReportButton => 'Report';

  @override
  String get alertTimeJustNow => 'Just now';

  @override
  String alertTimeMinutes(Object n) {
    return '$n min ago';
  }

  @override
  String alertTimeHours(Object n) {
    return '$n h ago';
  }

  @override
  String get alertsEmptyTitle => 'No active alerts nearby';

  @override
  String get alertsEmptySubtitle => 'See something on the road? Report it!';

  @override
  String get alertReportQuestion => 'What do you see on the road?';

  @override
  String get alertReportDescHint2 =>
      'Optional description… (e.g. \"large branch\")';

  @override
  String get alertReportedSuccess => 'Alert reported! Thank you 🙏';

  @override
  String get alertReportFailed => 'Could not report alert right now.';

  @override
  String get adBannerLoading => 'Loading ad…';

  @override
  String get adBannerWaitingRetry =>
      'Ad is waiting for network… (tap to retry)';

  @override
  String get mapStartNavigation => 'Start navigation';

  @override
  String get mapEndNavigation => 'End navigation';

  @override
  String get convoyShowAll => 'Show all';

  @override
  String get convoyYouBadge => 'You';

  @override
  String convoyShareCopied(Object name, Object code) {
    return 'Copied! Share: \"$name\" code: $code';
  }

  @override
  String convoyShareClipboard(Object name, Object code) {
    return 'CruizX convoy: \"$name\" (code: $code)';
  }

  @override
  String convoyPinMarkedBy(Object name) {
    return 'Marked by $name';
  }

  @override
  String get convoyNavigateToPin => 'Navigate here';

  @override
  String get convoyEtaArrived => 'Arrived!';

  @override
  String convoyEtaMinutes(Object minutes, Object time) {
    return '$minutes min · $time';
  }

  @override
  String convoyEtaHours(Object hours, Object minutes, Object time) {
    return '${hours}h ${minutes}min · $time';
  }

  @override
  String get paywallTitle => 'Upgrade to CruizX Pro';

  @override
  String get paywallSubtitle => 'No limits. No ads. Full access.';

  @override
  String get paywallPrice => '39 kr / month';

  @override
  String get paywallUpgradeButton => 'Upgrade to Pro';

  @override
  String paywallLifetimeButton(Object price) {
    return 'Buy Pro permanently · $price';
  }

  @override
  String get paywallRestoreButton => 'Restore purchase';

  @override
  String paywallDisclosure(Object price) {
    return 'CruizX Pro · $price/month · auto-renewing. Cancel anytime in Settings at least 24 hours before renewal. Charged to your Apple ID account.';
  }

  @override
  String paywallDisclosureAndroid(Object price) {
    return 'CruizX Pro · $price/month · auto-renewing. Managed and billed via Stripe. Cancel anytime at cruizx.com or by contacting support.';
  }

  @override
  String get paywallPriceOneTime => '249 kr';

  @override
  String paywallDisclosureOneTime(Object price) {
    return 'CruizX Pro · $price · one-time purchase. Charged once to your Apple ID. No subscription and no renewal.';
  }

  @override
  String get paywallFreeLabel => 'Free';

  @override
  String get paywallProLabel => 'Pro';

  @override
  String get paywallStartTrialButton => 'Start 7-day free trial';

  @override
  String paywallTrialNote(Object price) {
    return '7 days free, then $price as a one-time purchase.';
  }

  @override
  String get paywallFeatureRoutes => 'Navigation routes';

  @override
  String get paywallFreeRouteLimit => 'Unlimited';

  @override
  String get paywallProRouteLimit => 'Unlimited';

  @override
  String get paywallFeatureConvoy => 'Convoy';

  @override
  String get paywallFreeConvoyLimit => '1 active, 2 members';

  @override
  String get paywallProConvoyLimit => 'Unlimited';

  @override
  String get paywallFeatureAds => 'Ads';

  @override
  String get paywallFreeAds => 'Shown';

  @override
  String get paywallProAds => 'None';

  @override
  String get paywallRouteLimitTitle => 'Unlimited routes';

  @override
  String get paywallRouteLimitBody =>
      'Navigation routes are unlimited in the Free version too.';

  @override
  String get routeUpgradePromptTitle => 'Continue without ads?';

  @override
  String get routeUpgradePromptBody =>
      'You have created two routes today. Free includes unlimited routes, while Pro removes ads and unlocks more features. Would you like to upgrade?';

  @override
  String get paywallConvoyLimitTitle => 'Convoy limit reached';

  @override
  String get paywallConvoyLimitBody =>
      'Free users can only be in 1 convoy at a time.';

  @override
  String get paywallMemberLimitTitle => 'Convoy is full';

  @override
  String get paywallMemberLimitBody =>
      'Free users can only join convoys with fewer than 2 members. Upgrade to Pro for unlimited access.';

  @override
  String get paywallPurchaseSuccess => 'You are now a Pro user!';

  @override
  String get paywallPurchaseFailed =>
      'Purchase could not be completed. Please check your App Store account and try again.';

  @override
  String get paywallRestoreSuccess => 'Purchase restored!';

  @override
  String get paywallLoginRequiredTitle => 'Sign in required';

  @override
  String get paywallLoginRequiredBody =>
      'You need an account to purchase CruizX Pro. Create a free account in the app to continue.';

  @override
  String get paywallLoginRequiredAction => 'OK';

  @override
  String get paywallRestoreNotFound => 'No previous purchase found.';

  @override
  String get profileFreePlan => 'Free plan';

  @override
  String get profileProPlan => 'Pro plan';

  @override
  String get profileUpgradeToPro => 'Upgrade to Pro';

  @override
  String profileRoutesUsed(Object count) {
    return 'Routes today: $count';
  }

  @override
  String get profileChangePhoto => 'Change profile photo';

  @override
  String get profileTakePhoto => 'Take photo';

  @override
  String get profileChooseFromGallery => 'Choose from gallery';

  @override
  String get profilePhotoUploadFailed => 'Failed to upload photo';

  @override
  String get parentModeTitle => 'Parent Mode';

  @override
  String get parentModeDescription =>
      'Let a parent follow your driving in real-time.';

  @override
  String get parentModeLoginRequired =>
      'You must be logged in to use Parent Mode.';

  @override
  String get parentModeEnable => 'Enable Parent Mode';

  @override
  String get parentModeEnabledSubtitle => 'Parents can follow your driving';

  @override
  String get parentModeDisabledSubtitle => 'No sharing active';

  @override
  String get parentModeInviteCode => 'Invite Code';

  @override
  String get parentModeInviteCodeSubtitle =>
      'Share this code with your parent to link their account.';

  @override
  String get parentModeCopyCode => 'Copy';

  @override
  String get parentModeShareCode => 'Share';

  @override
  String get parentModeCodeCopied => 'Code copied!';

  @override
  String get parentModeShareSubject => 'CruizX Parent Code';

  @override
  String parentModeShareMessage(Object code) {
    return 'Hi! Use this code to follow my driving in CruizX: $code';
  }

  @override
  String get parentModeLinkedParents => 'Linked Parents';

  @override
  String get parentModeNoParentsLinked =>
      'No parents linked yet. Share your code!';

  @override
  String get parentModeUnlinkTitle => 'Remove parent?';

  @override
  String parentModeUnlinkMessage(Object name) {
    return 'Do you want to remove $name as a parent? They will no longer be able to follow your driving.';
  }

  @override
  String get parentModeUnlink => 'Remove';

  @override
  String get parentModeShareSettings => 'What to share';

  @override
  String get parentModeShareLocation => 'Share location';

  @override
  String get parentModeShareLocationSubtitle => 'Show where you are on the map';

  @override
  String get parentModeShareSpeed => 'Share speed';

  @override
  String get parentModeShareSpeedSubtitle => 'Show your current speed';

  @override
  String get parentModeAlertSettings => 'Notifications to parents';

  @override
  String get parentModeSpeedAlert => 'Speed alert';

  @override
  String parentModeSpeedAlertSubtitle(Object limit) {
    return 'Notify when speed exceeds $limit km/h';
  }

  @override
  String get parentModeSpeedLimit => 'Limit';

  @override
  String get parentModeNightAlert => 'Night driving alert';

  @override
  String parentModeNightAlertSubtitle(Object start, Object end) {
    return 'Notify when driving between $start–$end';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get login => 'Log in';

  @override
  String get parentDashboardTitle => 'Parent Dashboard';

  @override
  String get parentDashboardMapTab => 'Map';

  @override
  String get parentDashboardAlertsTab => 'Alerts';

  @override
  String get parentDashboardAddChild => 'Add child';

  @override
  String get parentDashboardOnline => 'Online';

  @override
  String get parentDashboardOffline => 'Offline';

  @override
  String get parentDashboardNoAlerts => 'No alerts in the last 24 hours';

  @override
  String get parentDashboardNoChildren => 'No children linked yet';

  @override
  String get parentDashboardNoChildrenHint =>
      'Add a child by entering their invite code from CruizX Parent Mode.';

  @override
  String get parentDashboardEnterCode => 'Enter invite code';

  @override
  String get parentDashboardEnterCodeHint =>
      'Ask your child to share their 6-character invite code from Parent Mode settings.';

  @override
  String get parentDashboardLink => 'Link';

  @override
  String get parentDashboardLinkSuccess => 'Successfully linked!';

  @override
  String get parentDashboardLinkFailed =>
      'Could not find child with that code. Check the code and try again.';

  @override
  String get parentDashboardLinkSelf =>
      'You cannot link to your own account. Ask your child to share their code from their account.';

  @override
  String get parentDashboardSpeedingAlert => 'Speed alert';

  @override
  String parentDashboardSpeedingDetail(
    Object name,
    Object speed,
    Object limit,
  ) {
    return '$name drove at $speed km/h (limit: $limit km/h)';
  }

  @override
  String get parentDashboardNightAlert => 'Night driving';

  @override
  String parentDashboardNightDetail(Object name) {
    return '$name is driving at night';
  }

  @override
  String get parentDashboardViewChild => 'View as parent';

  @override
  String get settingsVoiceNavigation => 'Voice navigation';

  @override
  String get settingsVoiceNavigationSubtitle => 'Read turn instructions aloud';

  @override
  String get voiceTurnLeft => 'Turn left';

  @override
  String get voiceTurnRight => 'Turn right';

  @override
  String get voiceTurnSharpLeft => 'Turn sharp left';

  @override
  String get voiceTurnSharpRight => 'Turn sharp right';

  @override
  String get voiceTurnSlightLeft => 'Turn slight left';

  @override
  String get voiceTurnSlightRight => 'Turn slight right';

  @override
  String get voiceContinue => 'Continue straight';

  @override
  String get voiceRoundabout => 'Enter the roundabout';

  @override
  String get voiceDestination => 'You have reached your destination';

  @override
  String voiceInMeters(Object meters) {
    return 'In $meters meters';
  }

  @override
  String voiceInKm(Object km) {
    return 'In $km kilometers';
  }

  @override
  String get mfaSetupTitle => 'Enable two-factor authentication';

  @override
  String get mfaSetupSubtitle =>
      'Scan the QR code with an authenticator app like Google Authenticator or Authy';

  @override
  String get mfaScanQr =>
      'Scan the code above and enter the 6-digit code below';

  @override
  String get mfaVerifyButton => 'Verify';

  @override
  String get mfaVerifyTitle => 'Two-factor authentication';

  @override
  String get mfaVerifySubtitle =>
      'Enter the 6-digit code from your authenticator app';

  @override
  String get mfaInvalidCode => 'Invalid code, try again';

  @override
  String get mfaCancel => 'Cancel and sign out';

  @override
  String get mfaProfileTitle => 'Two-factor authentication';

  @override
  String get mfaStatusOn => 'Enabled — your account is protected';

  @override
  String get mfaStatusOff => 'Disabled';

  @override
  String get mfaTurnOn => 'Enable';

  @override
  String get mfaTurnOff => 'Turn off';

  @override
  String get mfaDisableTitle => 'Turn off 2FA?';

  @override
  String get mfaDisableBody =>
      'Your account will be less secure without two-factor authentication.';

  @override
  String get mfaDisableConfirm => 'Turn off';

  @override
  String get mfaShowManualKey => 'Can\'t scan? Show key manually';

  @override
  String get mfaHideManualKey => 'Hide manual key';

  @override
  String get mfaKeyCopied => 'Key copied';

  @override
  String get mfaRecommendTitle => 'Protect your account';

  @override
  String get mfaRecommendBody =>
      'We recommend enabling two-factor authentication to protect your account. You can use an authenticator app like Google Authenticator or Authy.';

  @override
  String get mfaRecommendSetup => 'Enable now';

  @override
  String get mfaRecommendLater => 'Later';

  @override
  String get favHome => 'Home';

  @override
  String get favSchool => 'School';

  @override
  String get favWork => 'Work';

  @override
  String get favAddTitle => 'Save place';

  @override
  String get favLabelHint => 'Name (e.g. Friend)';

  @override
  String get favSaved => 'Place saved';

  @override
  String get favDeleted => 'Place removed';

  @override
  String favDeleteConfirm(Object name) {
    return 'Remove $name?';
  }

  @override
  String favSetAs(Object type) {
    return 'Save as $type';
  }

  @override
  String get favCustom => 'Other favorite';

  @override
  String get ttsVoiceHint =>
      'Tip: Download better voices in Settings → Accessibility → Spoken Content → Voices';

  @override
  String get ttsVoiceHintDismiss => 'OK';

  @override
  String get settingsVectorMap => 'Vector map';

  @override
  String get settingsVectorMapOn =>
      'Sharp rendering at all zoom levels, smooth zoom';

  @override
  String get settingsVectorMapOff => 'Standard — fast and offline-cached';

  @override
  String get publicGatheringStartTime => 'Start time';

  @override
  String get publicGatheringEndTime => 'End time';

  @override
  String get publicGatheringScheduleInvalid =>
      'The end time must be after the start time.';

  @override
  String get publicGatheringEndAction => 'End meetup';

  @override
  String get publicGatheringDeleteAction => 'Delete meetup';

  @override
  String get publicGatheringEndConfirm =>
      'End the meetup now? Participants will no longer be able to find it.';

  @override
  String get publicGatheringDeleteConfirm =>
      'Permanently delete this meetup? This cannot be undone.';

  @override
  String get publicGatheringReportAction => 'Report meetup';

  @override
  String get publicGatheringBlockAction => 'Block meetup';

  @override
  String get publicGatheringReportParticipant => 'Report participant';

  @override
  String get publicGatheringBlockParticipant => 'Block participant';

  @override
  String get publicGatheringReportReason => 'What would you like to report?';

  @override
  String get publicGatheringReportSent => 'Your report has been sent.';

  @override
  String get publicGatheringBlocked =>
      'Blocked content will no longer be shown.';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonHarassment => 'Harassment';

  @override
  String get reportReasonDangerous => 'Dangerous behavior';

  @override
  String get reportReasonSpam => 'Spam or misleading';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get publicGatheringNearbyNotifications =>
      'Nearby meetup notifications';

  @override
  String get publicGatheringNearbyNotificationsSubtitle =>
      'Notify me once when a public meetup within 25 km starts within 24 hours.';

  @override
  String get publicGatheringUpcoming => 'Upcoming';

  @override
  String get publicGatheringStarted => 'In progress';

  @override
  String get aiRouteButton => 'AI route check';

  @override
  String get aiRouteTitle => 'CruizX AI route analysis';

  @override
  String get aiConsentTitle => 'Use AI route analysis?';

  @override
  String get aiConsentBody =>
      'CruizX uses route facts such as distance, travel time, vehicle type, road names and warning counts to analyze the route. Your exact position, destination coordinates and identity are not shared. The analysis may contain errors and never changes your route.';

  @override
  String get aiConsentAccept => 'Agree and continue';

  @override
  String get aiConsentDecline => 'Not now';

  @override
  String get aiSignInRequired => 'Sign in to use AI route analysis.';

  @override
  String get aiLoading => 'Checking the route…';

  @override
  String get aiUnavailable =>
      'AI route analysis is unavailable right now. Your route is unchanged.';

  @override
  String get aiDailyLimit =>
      'You have reached today\'s limit of AI route analyses.';

  @override
  String get aiHighlights => 'Highlights';

  @override
  String get aiCautions => 'Things to check';

  @override
  String get aiRecommendation => 'Recommendation';

  @override
  String get aiDisclaimer =>
      'AI summary based only on available route data. Check signs and current road conditions.';

  @override
  String get aiReport => 'Report answer';

  @override
  String get aiReportTitle => 'Why are you reporting this answer?';

  @override
  String get aiReportIncorrect => 'Incorrect information';

  @override
  String get aiReportUnsafe => 'Unsafe advice';

  @override
  String get aiReportInappropriate => 'Inappropriate content';

  @override
  String get aiReportOther => 'Other problem';

  @override
  String get aiReportSent => 'Thanks. The AI answer has been reported.';
}
