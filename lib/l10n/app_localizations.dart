import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sv')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SlowRide'**
  String get appTitle;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get navAlerts;

  /// No description provided for @navConvoy.
  ///
  /// In en, this message translates to:
  /// **'Convoy'**
  String get navConvoy;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @splashPreparingStartup.
  ///
  /// In en, this message translates to:
  /// **'Preparing startup...'**
  String get splashPreparingStartup;

  /// No description provided for @splashLoadingCoreModules.
  ///
  /// In en, this message translates to:
  /// **'Loading core modules...'**
  String get splashLoadingCoreModules;

  /// No description provided for @splashInitializingAccountSession.
  ///
  /// In en, this message translates to:
  /// **'Initializing account session...'**
  String get splashInitializingAccountSession;

  /// No description provided for @splashLoadingPreferences.
  ///
  /// In en, this message translates to:
  /// **'Loading preferences...'**
  String get splashLoadingPreferences;

  /// No description provided for @splashFinalizingStartup.
  ///
  /// In en, this message translates to:
  /// **'Finalizing startup...'**
  String get splashFinalizingStartup;

  /// No description provided for @splashReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get splashReady;

  /// No description provided for @splashVersionLine.
  ///
  /// In en, this message translates to:
  /// **'v1.0.0 | SlowRide by KimTechTool'**
  String get splashVersionLine;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Alerts'**
  String get alertsTitle;

  /// No description provided for @alertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report and view road hazards, checks, and road conditions.'**
  String get alertsSubtitle;

  /// No description provided for @convoyRequiresSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Convoy requires sign in'**
  String get convoyRequiresSignInTitle;

  /// No description provided for @convoyRequiresSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account here to create convoy groups and see live locations.'**
  String get convoyRequiresSignInSubtitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signInEmailDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email OTP'**
  String get signInEmailDialogTitle;

  /// No description provided for @signUpEmailDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account with email OTP'**
  String get signUpEmailDialogTitle;

  /// No description provided for @signInEmailFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get signInEmailFieldLabel;

  /// No description provided for @signInEmailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get signInEmailHint;

  /// No description provided for @signInSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get signInSendOtp;

  /// No description provided for @signUpSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send account code'**
  String get signUpSendOtp;

  /// No description provided for @signInOtpFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'OTP code'**
  String get signInOtpFieldLabel;

  /// No description provided for @signInOtpHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get signInOtpHint;

  /// No description provided for @signInVerifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get signInVerifyOtp;

  /// No description provided for @signInOtpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP code sent to your email.'**
  String get signInOtpSent;

  /// No description provided for @signUpOtpSent.
  ///
  /// In en, this message translates to:
  /// **'Account creation code sent to your email.'**
  String get signUpOtpSent;

  /// No description provided for @signInOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Could not verify OTP. Check your code and try again.'**
  String get signInOtpInvalid;

  /// No description provided for @signUpNoAccountAction.
  ///
  /// In en, this message translates to:
  /// **'No account? Create one'**
  String get signUpNoAccountAction;

  /// No description provided for @signUpHaveAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get signUpHaveAccountAction;

  /// No description provided for @convoyRealtimeBackendMissing.
  ///
  /// In en, this message translates to:
  /// **'Realtime convoy is not configured yet. Add backend config to share live positions between users.'**
  String get convoyRealtimeBackendMissing;

  /// No description provided for @convoyModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Convoy Mode'**
  String get convoyModeTitle;

  /// No description provided for @convoyModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create group driving with a shared destination and live locations.'**
  String get convoyModeSubtitle;

  /// No description provided for @convoyCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create convoy'**
  String get convoyCreateButton;

  /// No description provided for @convoyJoinButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get convoyJoinButton;

  /// No description provided for @convoyLeaveButton.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get convoyLeaveButton;

  /// No description provided for @convoyJoinFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Join the convoy first, then tap it to open chat and map.'**
  String get convoyJoinFirstHint;

  /// No description provided for @convoyTabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get convoyTabMap;

  /// No description provided for @convoyTabChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get convoyTabChat;

  /// No description provided for @convoyMapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap map to place a shared pin.'**
  String get convoyMapHint;

  /// No description provided for @convoyRecenterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Recenter and follow my position'**
  String get convoyRecenterTooltip;

  /// No description provided for @convoyPinDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add map pin'**
  String get convoyPinDialogTitle;

  /// No description provided for @convoyPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Pin label'**
  String get convoyPinLabel;

  /// No description provided for @convoyPinHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Meet here'**
  String get convoyPinHint;

  /// No description provided for @convoyPinAdd.
  ///
  /// In en, this message translates to:
  /// **'Add pin'**
  String get convoyPinAdd;

  /// No description provided for @convoyHazardPolice.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get convoyHazardPolice;

  /// No description provided for @convoyHazardRoadwork.
  ///
  /// In en, this message translates to:
  /// **'Roadwork'**
  String get convoyHazardRoadwork;

  /// No description provided for @convoyHazardAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get convoyHazardAccident;

  /// No description provided for @convoyHazardTrafficJam.
  ///
  /// In en, this message translates to:
  /// **'Traffic jam'**
  String get convoyHazardTrafficJam;

  /// No description provided for @convoyHazardSpeedCamera.
  ///
  /// In en, this message translates to:
  /// **'Speed camera'**
  String get convoyHazardSpeedCamera;

  /// No description provided for @convoyHazardCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom pin'**
  String get convoyHazardCustom;

  /// No description provided for @convoyChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get convoyChatEmpty;

  /// No description provided for @convoyChatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write a message...'**
  String get convoyChatPlaceholder;

  /// No description provided for @convoyChatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get convoyChatSend;

  /// No description provided for @convoyNameDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create convoy'**
  String get convoyNameDialogTitle;

  /// No description provided for @convoyNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Convoy name'**
  String get convoyNameFieldLabel;

  /// No description provided for @convoyNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Friday Night Ride'**
  String get convoyNameHint;

  /// No description provided for @convoyCreateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get convoyCreateConfirm;

  /// No description provided for @convoyCreateCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get convoyCreateCancel;

  /// No description provided for @convoyListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No convoys yet. Create the first one.'**
  String get convoyListEmpty;

  /// No description provided for @convoyListEmptyMine.
  ///
  /// In en, this message translates to:
  /// **'You have not joined any convoys yet.'**
  String get convoyListEmptyMine;

  /// No description provided for @convoyFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get convoyFilterAll;

  /// No description provided for @convoyFilterMine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get convoyFilterMine;

  /// No description provided for @convoyMembers.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String convoyMembers(Object count);

  /// No description provided for @convoyCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by {leader}'**
  String convoyCreatedBy(Object leader);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile & Stats'**
  String get profileTitle;

  /// No description provided for @profileNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'You are not signed in.'**
  String get profileNotSignedIn;

  /// No description provided for @profileSignInInConvoyHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in is available in the Convoy tab.'**
  String get profileSignInInConvoyHint;

  /// No description provided for @profileSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as: {name}'**
  String profileSignedInAs(Object name);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageSwedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get settingsLanguageSwedish;

  /// No description provided for @settingsLanguageCurrentlyUsing.
  ///
  /// In en, this message translates to:
  /// **'Currently using: {mode}'**
  String settingsLanguageCurrentlyUsing(Object mode);

  /// No description provided for @settingsVehicleTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get settingsVehicleTypeLabel;

  /// No description provided for @settingsVehicleAtractor.
  ///
  /// In en, this message translates to:
  /// **'A-tractor'**
  String get settingsVehicleAtractor;

  /// No description provided for @settingsVehicleMopedCar.
  ///
  /// In en, this message translates to:
  /// **'Moped car'**
  String get settingsVehicleMopedCar;

  /// No description provided for @settingsVehicleTractor.
  ///
  /// In en, this message translates to:
  /// **'Tractor'**
  String get settingsVehicleTractor;

  /// No description provided for @settingsSpeedUnitKmh.
  ///
  /// In en, this message translates to:
  /// **'km/h'**
  String get settingsSpeedUnitKmh;

  /// No description provided for @settingsSpeedUnitMph.
  ///
  /// In en, this message translates to:
  /// **'mph'**
  String get settingsSpeedUnitMph;

  /// No description provided for @settingsMaxSpeedWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Max speed: {value} {unit}'**
  String settingsMaxSpeedWithUnit(Object value, Object unit);

  /// No description provided for @navigationTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn-by-Turn Navigation'**
  String get navigationTitle;

  /// No description provided for @navigationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Directions, next turn, and ETA optimized for slow vehicles.'**
  String get navigationSubtitle;

  /// No description provided for @mapStartingGps.
  ///
  /// In en, this message translates to:
  /// **'Starting GPS...'**
  String get mapStartingGps;

  /// No description provided for @mapTapToSelectDestination.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to select a destination'**
  String get mapTapToSelectDestination;

  /// No description provided for @mapAddressFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Search address (e.g. Main St 10, Stockholm)'**
  String get mapAddressFieldHint;

  /// No description provided for @mapSearchingAddress.
  ///
  /// In en, this message translates to:
  /// **'Searching address...'**
  String get mapSearchingAddress;

  /// No description provided for @mapAddressNotFound.
  ///
  /// In en, this message translates to:
  /// **'No address found. Try again.'**
  String get mapAddressNotFound;

  /// No description provided for @mapAddressLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not search address right now'**
  String get mapAddressLookupFailed;

  /// No description provided for @mapLocationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled'**
  String get mapLocationServicesDisabled;

  /// No description provided for @mapLocationPermissionMissing.
  ///
  /// In en, this message translates to:
  /// **'Location permission is missing'**
  String get mapLocationPermissionMissing;

  /// No description provided for @mapGpsActive.
  ///
  /// In en, this message translates to:
  /// **'GPS active'**
  String get mapGpsActive;

  /// No description provided for @mapGpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'GPS is unavailable in this environment'**
  String get mapGpsUnavailable;

  /// No description provided for @mapWaitingForGps.
  ///
  /// In en, this message translates to:
  /// **'Waiting for GPS position before route calculation'**
  String get mapWaitingForGps;

  /// No description provided for @mapCalculatingRoute.
  ///
  /// In en, this message translates to:
  /// **'Calculating route...'**
  String get mapCalculatingRoute;

  /// No description provided for @mapRouteReady.
  ///
  /// In en, this message translates to:
  /// **'Route ready: {distance} km • {minutes} min'**
  String mapRouteReady(Object distance, Object minutes);

  /// No description provided for @mapRouteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create route right now'**
  String get mapRouteFailed;

  /// No description provided for @mapRouteNoRouteFound.
  ///
  /// In en, this message translates to:
  /// **'No route found between selected points'**
  String get mapRouteNoRouteFound;

  /// No description provided for @mapRouteProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Routing service is unavailable right now'**
  String get mapRouteProviderUnavailable;

  /// No description provided for @mapRouteMissingApiKey.
  ///
  /// In en, this message translates to:
  /// **'Routing is not configured on backend (missing API key)'**
  String get mapRouteMissingApiKey;

  /// No description provided for @mapRouteInvalidGeometry.
  ///
  /// In en, this message translates to:
  /// **'Route data from server is invalid'**
  String get mapRouteInvalidGeometry;

  /// No description provided for @mapRouteUnknownProvider.
  ///
  /// In en, this message translates to:
  /// **'Routing provider is not configured correctly'**
  String get mapRouteUnknownProvider;

  /// No description provided for @mapRouteTooFastForVehicle.
  ///
  /// In en, this message translates to:
  /// **'Route rejected: estimated average speed is too high for this vehicle type.'**
  String get mapRouteTooFastForVehicle;

  /// No description provided for @mapRouteNotAllowedForVehicle.
  ///
  /// In en, this message translates to:
  /// **'No legally compliant route found for this vehicle type.'**
  String get mapRouteNotAllowedForVehicle;

  /// No description provided for @speedometerLiveSpeed.
  ///
  /// In en, this message translates to:
  /// **'Live speed'**
  String get speedometerLiveSpeed;

  /// No description provided for @speedometerMaxSpeedWithUnit.
  ///
  /// In en, this message translates to:
  /// **'Max speed: {value} {unit}'**
  String speedometerMaxSpeedWithUnit(Object value, Object unit);

  /// No description provided for @speedometerSlowDown.
  ///
  /// In en, this message translates to:
  /// **'Slow down.'**
  String get speedometerSlowDown;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'sv': return AppLocalizationsSv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
