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
  String get splashInitializingAccountSession => 'Initializing account session...';

  @override
  String get splashLoadingPreferences => 'Loading preferences...';

  @override
  String get splashFinalizingStartup => 'Finalizing startup...';

  @override
  String get splashReady => 'Ready';

  @override
  String get splashVersionLine => 'v1.0.0 | CruizX by KimTechTool';

  @override
  String get alertsTitle => 'Community Alerts';

  @override
  String get alertsSubtitle => 'Report and view road hazards, checks, and road conditions.';

  @override
  String get convoyRequiresSignInTitle => 'Convoy requires sign in';

  @override
  String get convoyRequiresSignInSubtitle => 'Sign in or create an account here to create convoy groups and see live locations.';

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
  String get signInOtpInvalid => 'Could not verify OTP. Check your code and try again.';

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
  String get authPasswordMinLength => 'At least 6 characters';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authConfirmPasswordRequired => 'Confirm your password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

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
  String get authErrorAllFieldsRequired => 'All fields are required.';

  @override
  String get authErrorPasswordTooShort => 'Password must be at least 6 characters.';

  @override
  String get authErrorConfirmEmail => 'Check your email to confirm your account, then sign in.';

  @override
  String get authErrorEmailAndPasswordRequired => 'Enter your email and password.';

  @override
  String get authErrorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get authErrorEmailAlreadyInUse => 'An account with that email already exists.';

  @override
  String get convoyRealtimeBackendMissing => 'Realtime convoy is not configured yet. Add backend config to share live positions between users.';

  @override
  String get convoyModeTitle => 'Convoy Mode';

  @override
  String get convoyModeSubtitle => 'Create group driving with a shared destination and live locations.';

  @override
  String get convoyCreateButton => 'Create convoy';

  @override
  String get convoyOpenButton => 'Open';

  @override
  String get convoyJoinButton => 'Join';

  @override
  String get convoyLeaveButton => 'Leave';

  @override
  String get convoyJoinFirstHint => 'Join the convoy first, then tap it to open chat and map.';

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
  String get profileSignInInConvoyHint => 'Sign in is available in the Convoy tab.';

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
  String settingsLanguageCurrentlyUsing(Object mode) {
    return 'Currently using: $mode';
  }

  @override
  String get settingsVehicleTypeLabel => 'Vehicle type';

  @override
  String get settingsVehicleAtractor => 'A-tractor';

  @override
  String get settingsVehicleMopedCar => 'Moped car';

  @override
  String get settingsVehicleTractor => 'Tractor';

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
  String get settingsProDescriptionActive => 'You have access to all Pro features.';

  @override
  String get settingsProDescriptionInactive => 'Unlock all features with CruizX Pro.';

  @override
  String get settingsPrivacyPolicyLabel => 'Privacy Policy';

  @override
  String get settingsTermsOfUseLabel => 'Terms of Use (EULA)';

  @override
  String get settingsLinkOpenFailed => 'Could not open the link right now.';

  @override
  String get settingsRestorePurchaseFailed => 'Could not restore purchase.';

  @override
  String get navigationTitle => 'Turn-by-Turn Navigation';

  @override
  String get navigationSubtitle => 'Directions, next turn, and ETA optimized for slow vehicles.';

  @override
  String get mapStartingGps => 'Starting GPS...';

  @override
  String get mapTapToSelectDestination => 'Tap the map to select a destination';

  @override
  String get mapAddressFieldHint => 'Search address (e.g. Main St 10, Stockholm)';

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
  String get mapWaitingForGps => 'Waiting for GPS position before route calculation';

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
  String get mapRouteProviderUnavailable => 'Routing service is unavailable right now';

  @override
  String get mapRouteMissingApiKey => 'Routing is not configured on backend (missing API key)';

  @override
  String get mapRouteInvalidGeometry => 'Route data from server is invalid';

  @override
  String get mapRouteUnknownProvider => 'Routing provider is not configured correctly';

  @override
  String get mapRouteTooFastForVehicle => 'Route rejected: estimated average speed is too high for this vehicle type.';

  @override
  String get mapRouteNotAllowedForVehicle => 'No legally compliant route found for this vehicle type.';

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
  String get alertGpsUnavailable => 'GPS not available yet';

  @override
  String get alertMustBeLoggedIn => 'You must be signed in to report';

  @override
  String get alertsScreenSubtitle => 'Alerts from other CruizX drivers within ~50 km. Tap thumbs to confirm an alert.';

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
  String get alertReportDescHint2 => 'Optional description… (e.g. \"large branch\")';

  @override
  String get alertReportedSuccess => 'Alert reported! Thank you 🙏';

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
  String get paywallTitle => 'Upgrade to CruizX Pro';

  @override
  String get paywallSubtitle => 'No limits. No ads. Full access.';

  @override
  String get paywallPrice => '3.49 \$ / month';

  @override
  String get paywallUpgradeButton => 'Upgrade to Pro';

  @override
  String get paywallRestoreButton => 'Restore purchase';

  @override
  String get paywallFreeLabel => 'Free';

  @override
  String get paywallProLabel => 'Pro';

  @override
  String get paywallFeatureRoutes => 'Routes per day';

  @override
  String get paywallFreeRouteLimit => '2 routes';

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
  String get paywallRouteLimitTitle => 'Route limit reached';

  @override
  String get paywallRouteLimitBody => 'Free users can calculate 2 routes per day. Upgrade to Pro for unlimited navigation.';

  @override
  String get paywallConvoyLimitTitle => 'Convoy limit reached';

  @override
  String get paywallConvoyLimitBody => 'Free users can only be in 1 convoy at a time.';

  @override
  String get paywallMemberLimitTitle => 'Convoy is full';

  @override
  String get paywallMemberLimitBody => 'Free users can only join convoys with fewer than 2 members. Upgrade to Pro for unlimited access.';

  @override
  String get paywallPurchaseSuccess => 'You are now a Pro user!';

  @override
  String get paywallRestoreSuccess => 'Purchase restored!';

  @override
  String get paywallRestoreNotFound => 'No previous purchase found.';

  @override
  String get profileFreePlan => 'Free plan';

  @override
  String get profileProPlan => 'Pro plan';

  @override
  String get profileUpgradeToPro => 'Upgrade to Pro';

  @override
  String profileRoutesUsed(Object count, Object max) {
    return 'Routes today: $count / $max';
  }
}
