import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_da.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_nb.dart';
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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('da'),
    Locale('en'),
    Locale('es'),
    Locale('fi'),
    Locale('fr'),
    Locale('nb'),
    Locale('sv'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CruizX'**
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
  /// **'v1.0.5 | CruizX by KimTechTool'**
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

  /// No description provided for @authGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authGenericError;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back to CruizX'**
  String get authWelcomeBack;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join the CruizX community'**
  String get authRegisterSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get authEmailLabel;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get authPasswordMinLength;

  /// No description provided for @authConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPasswordLabel;

  /// No description provided for @authConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get authConfirmPasswordRequired;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get authDisplayNameLabel;

  /// No description provided for @authDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get authDisplayNameRequired;

  /// No description provided for @authNoAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'No account? '**
  String get authNoAccountPrompt;

  /// No description provided for @authAlreadyHaveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authAlreadyHaveAccountPrompt;

  /// No description provided for @authCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get authCancel;

  /// No description provided for @authForgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPasswordLink;

  /// No description provided for @authForgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authForgotPasswordTitle;

  /// No description provided for @authForgotPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get authForgotPasswordDescription;

  /// No description provided for @authForgotPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authForgotPasswordButton;

  /// No description provided for @authForgotPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'If the account exists, we\'ve sent a reset link to your email.'**
  String get authForgotPasswordSuccess;

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authResetPasswordTitle;

  /// No description provided for @authResetPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password below.'**
  String get authResetPasswordDescription;

  /// No description provided for @authNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPasswordLabel;

  /// No description provided for @authResetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get authResetPasswordButton;

  /// No description provided for @authResetPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed.'**
  String get authResetPasswordSuccess;

  /// No description provided for @authErrorAllFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'All fields are required.'**
  String get authErrorAllFieldsRequired;

  /// No description provided for @authErrorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authErrorPasswordTooShort;

  /// No description provided for @authErrorConfirmEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm your account, then sign in.'**
  String get authErrorConfirmEmail;

  /// No description provided for @authErrorEmailAndPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password.'**
  String get authErrorEmailAndPasswordRequired;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'An account with that email already exists.'**
  String get authErrorEmailAlreadyInUse;

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

  /// No description provided for @convoyOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get convoyOpenButton;

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

  /// No description provided for @convoyJoinByCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Join convoy'**
  String get convoyJoinByCodeTitle;

  /// No description provided for @convoyJoinByCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the convoy code you received'**
  String get convoyJoinByCodeHint;

  /// No description provided for @convoyJoinWithCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get convoyJoinWithCodeButton;

  /// No description provided for @convoyJoinByCodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'No convoy found with that code.'**
  String get convoyJoinByCodeNotFound;

  /// No description provided for @convoyJoinByCodeSuccess.
  ///
  /// In en, this message translates to:
  /// **'You joined {name}!'**
  String convoyJoinByCodeSuccess(String name);

  /// No description provided for @convoyInviteButton.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get convoyInviteButton;

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

  /// No description provided for @convoyMemberMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get convoyMemberMe;

  /// No description provided for @convoyMemberStaleTime.
  ///
  /// In en, this message translates to:
  /// **'{mins}m ago'**
  String convoyMemberStaleTime(Object mins);

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

  /// No description provided for @profileDefaultName.
  ///
  /// In en, this message translates to:
  /// **'CruizX Driver'**
  String get profileDefaultName;

  /// No description provided for @profileSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get profileSignedIn;

  /// No description provided for @profileStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get profileStatsTitle;

  /// No description provided for @profileStatsConvoys.
  ///
  /// In en, this message translates to:
  /// **'Convoys driven'**
  String get profileStatsConvoys;

  /// No description provided for @profileStatsTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'Total distance'**
  String get profileStatsTotalDistance;

  /// No description provided for @profileStatsSpeedViolations.
  ///
  /// In en, this message translates to:
  /// **'Speed violations'**
  String get profileStatsSpeedViolations;

  /// No description provided for @profileVehicleTitle.
  ///
  /// In en, this message translates to:
  /// **'My vehicle'**
  String get profileVehicleTitle;

  /// No description provided for @profileVehicleElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric vehicle'**
  String get profileVehicleElectric;

  /// No description provided for @profileVehicleElectricSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show charging stations on the map'**
  String get profileVehicleElectricSubtitle;

  /// No description provided for @profileVehicleStuddedTires.
  ///
  /// In en, this message translates to:
  /// **'Studded tires'**
  String get profileVehicleStuddedTires;

  /// No description provided for @profileVehicleStuddedTiresSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Avoid streets with studded tire bans'**
  String get profileVehicleStuddedTiresSubtitle;

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

  /// No description provided for @settingsLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get settingsLanguageFrench;

  /// No description provided for @settingsLanguageNorwegian.
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get settingsLanguageNorwegian;

  /// No description provided for @settingsLanguageDanish.
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get settingsLanguageDanish;

  /// No description provided for @settingsLanguageFinnish.
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get settingsLanguageFinnish;

  /// No description provided for @settingsLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get settingsLanguageSpanish;

  /// No description provided for @settingsCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country (traffic rules)'**
  String get settingsCountryLabel;

  /// No description provided for @settingsCountrySweden.
  ///
  /// In en, this message translates to:
  /// **'🇸🇪 Sweden'**
  String get settingsCountrySweden;

  /// No description provided for @settingsCountryNorway.
  ///
  /// In en, this message translates to:
  /// **'🇳🇴 Norway'**
  String get settingsCountryNorway;

  /// No description provided for @settingsCountryDenmark.
  ///
  /// In en, this message translates to:
  /// **'🇩🇰 Denmark'**
  String get settingsCountryDenmark;

  /// No description provided for @settingsCountryFinland.
  ///
  /// In en, this message translates to:
  /// **'🇫🇮 Finland'**
  String get settingsCountryFinland;

  /// No description provided for @settingsCountryFrance.
  ///
  /// In en, this message translates to:
  /// **'🇫🇷 France'**
  String get settingsCountryFrance;

  /// No description provided for @settingsCountrySpain.
  ///
  /// In en, this message translates to:
  /// **'🇪🇸 Spain'**
  String get settingsCountrySpain;

  /// No description provided for @settingsCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Speed limits and road rules adapt to the selected country.'**
  String get settingsCountryHint;

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

  /// No description provided for @settingsProCardTitle.
  ///
  /// In en, this message translates to:
  /// **'CruizX Pro'**
  String get settingsProCardTitle;

  /// No description provided for @settingsProStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settingsProStatusActive;

  /// No description provided for @settingsProStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Not active'**
  String get settingsProStatusInactive;

  /// No description provided for @settingsProDescriptionActive.
  ///
  /// In en, this message translates to:
  /// **'You have access to all Pro features.'**
  String get settingsProDescriptionActive;

  /// No description provided for @settingsProDescriptionInactive.
  ///
  /// In en, this message translates to:
  /// **'Unlock all features with CruizX Pro.'**
  String get settingsProDescriptionInactive;

  /// No description provided for @settingsProFeatureRoutes.
  ///
  /// In en, this message translates to:
  /// **'Unlimited routes'**
  String get settingsProFeatureRoutes;

  /// No description provided for @settingsProFeatureConvoy.
  ///
  /// In en, this message translates to:
  /// **'Unlimited convoy members'**
  String get settingsProFeatureConvoy;

  /// No description provided for @settingsProFeatureAds.
  ///
  /// In en, this message translates to:
  /// **'No ads'**
  String get settingsProFeatureAds;

  /// No description provided for @settingsProFeatureSupport.
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get settingsProFeatureSupport;

  /// No description provided for @settingsProSubscriptionNote.
  ///
  /// In en, this message translates to:
  /// **'Subscription: CruizX Pro Monthly (1 month). Payment is charged to your Apple ID and renews automatically unless canceled at least 24 hours before the end of the current period.'**
  String get settingsProSubscriptionNote;

  /// No description provided for @settingsProPricePerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String settingsProPricePerMonth(Object price);

  /// No description provided for @settingsPrivacyPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicyLabel;

  /// No description provided for @settingsTermsOfUseLabel.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use (EULA)'**
  String get settingsTermsOfUseLabel;

  /// No description provided for @settingsSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupportLabel;

  /// No description provided for @settingsLinkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link right now.'**
  String get settingsLinkOpenFailed;

  /// No description provided for @settingsRestorePurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore purchase.'**
  String get settingsRestorePurchaseFailed;

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

  /// No description provided for @mapRemaining.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get mapRemaining;

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

  /// No description provided for @routeBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Route not available'**
  String get routeBlockedTitle;

  /// No description provided for @routeBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'No legal route was found to this destination for your {vehicleType}. The destination may be on or only reachable via roads that are not allowed for this vehicle type (e.g. motorways).'**
  String routeBlockedBody(Object vehicleType);

  /// No description provided for @routeBlockedOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get routeBlockedOk;

  /// No description provided for @routeBlockedTryOther.
  ///
  /// In en, this message translates to:
  /// **'Try a different destination'**
  String get routeBlockedTryOther;

  /// No description provided for @mapModeLabel2d.
  ///
  /// In en, this message translates to:
  /// **'2D'**
  String get mapModeLabel2d;

  /// No description provided for @mapModeLabel3d.
  ///
  /// In en, this message translates to:
  /// **'3D'**
  String get mapModeLabel3d;

  /// No description provided for @mapManeuverInDistance.
  ///
  /// In en, this message translates to:
  /// **'In {distance}'**
  String mapManeuverInDistance(Object distance);

  /// No description provided for @mapManeuverTowardRoad.
  ///
  /// In en, this message translates to:
  /// **'Toward {road}'**
  String mapManeuverTowardRoad(Object road);

  /// No description provided for @mapSimulateButton.
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get mapSimulateButton;

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

  /// No description provided for @reportAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Report alert'**
  String get reportAlertTitle;

  /// No description provided for @reportAlertDescHint.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get reportAlertDescHint;

  /// No description provided for @reportAlertSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit alert'**
  String get reportAlertSubmit;

  /// No description provided for @reportAlertNearby.
  ///
  /// In en, this message translates to:
  /// **'{type} · {distance} m ahead'**
  String reportAlertNearby(Object type, Object distance);

  /// No description provided for @alertTypePolice.
  ///
  /// In en, this message translates to:
  /// **'Police'**
  String get alertTypePolice;

  /// No description provided for @alertTypeRoadwork.
  ///
  /// In en, this message translates to:
  /// **'Roadwork'**
  String get alertTypeRoadwork;

  /// No description provided for @alertTypeAccident.
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get alertTypeAccident;

  /// No description provided for @alertTypeTrafficJam.
  ///
  /// In en, this message translates to:
  /// **'Traffic jam'**
  String get alertTypeTrafficJam;

  /// No description provided for @alertTypeSpeedCamera.
  ///
  /// In en, this message translates to:
  /// **'Speed camera'**
  String get alertTypeSpeedCamera;

  /// No description provided for @alertTypeHazard.
  ///
  /// In en, this message translates to:
  /// **'Hazard'**
  String get alertTypeHazard;

  /// No description provided for @alertTypeNarrowRoad.
  ///
  /// In en, this message translates to:
  /// **'Narrow road'**
  String get alertTypeNarrowRoad;

  /// No description provided for @alertTypeSteepHill.
  ///
  /// In en, this message translates to:
  /// **'Steep hill'**
  String get alertTypeSteepHill;

  /// No description provided for @alertGpsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'GPS not available yet'**
  String get alertGpsUnavailable;

  /// No description provided for @alertMustBeLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'You must be signed in to report'**
  String get alertMustBeLoggedIn;

  /// No description provided for @alertsScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts from other CruizX drivers within ~50 km. Tap thumbs to confirm an alert.'**
  String get alertsScreenSubtitle;

  /// No description provided for @alertReportButton.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get alertReportButton;

  /// No description provided for @alertTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get alertTimeJustNow;

  /// No description provided for @alertTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String alertTimeMinutes(Object n);

  /// No description provided for @alertTimeHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String alertTimeHours(Object n);

  /// No description provided for @alertsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No active alerts nearby'**
  String get alertsEmptyTitle;

  /// No description provided for @alertsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'See something on the road? Report it!'**
  String get alertsEmptySubtitle;

  /// No description provided for @alertReportQuestion.
  ///
  /// In en, this message translates to:
  /// **'What do you see on the road?'**
  String get alertReportQuestion;

  /// No description provided for @alertReportDescHint2.
  ///
  /// In en, this message translates to:
  /// **'Optional description… (e.g. \"large branch\")'**
  String get alertReportDescHint2;

  /// No description provided for @alertReportedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Alert reported! Thank you 🙏'**
  String get alertReportedSuccess;

  /// No description provided for @alertReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not report alert right now.'**
  String get alertReportFailed;

  /// No description provided for @adBannerLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading ad…'**
  String get adBannerLoading;

  /// No description provided for @adBannerWaitingRetry.
  ///
  /// In en, this message translates to:
  /// **'Ad is waiting for network… (tap to retry)'**
  String get adBannerWaitingRetry;

  /// No description provided for @mapStartNavigation.
  ///
  /// In en, this message translates to:
  /// **'Start navigation'**
  String get mapStartNavigation;

  /// No description provided for @mapEndNavigation.
  ///
  /// In en, this message translates to:
  /// **'End navigation'**
  String get mapEndNavigation;

  /// No description provided for @convoyShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get convoyShowAll;

  /// No description provided for @convoyYouBadge.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get convoyYouBadge;

  /// No description provided for @convoyShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied! Share: \"{name}\" code: {code}'**
  String convoyShareCopied(Object name, Object code);

  /// No description provided for @convoyShareClipboard.
  ///
  /// In en, this message translates to:
  /// **'CruizX convoy: \"{name}\" (code: {code})'**
  String convoyShareClipboard(Object name, Object code);

  /// No description provided for @convoyPinMarkedBy.
  ///
  /// In en, this message translates to:
  /// **'Marked by {name}'**
  String convoyPinMarkedBy(Object name);

  /// No description provided for @convoyNavigateToPin.
  ///
  /// In en, this message translates to:
  /// **'Navigate here'**
  String get convoyNavigateToPin;

  /// No description provided for @convoyEtaArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived!'**
  String get convoyEtaArrived;

  /// No description provided for @convoyEtaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min · {time}'**
  String convoyEtaMinutes(Object minutes, Object time);

  /// No description provided for @convoyEtaHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}min · {time}'**
  String convoyEtaHours(Object hours, Object minutes, Object time);

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to CruizX Pro'**
  String get paywallTitle;

  /// No description provided for @paywallSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No limits. No ads. Full access.'**
  String get paywallSubtitle;

  /// No description provided for @paywallPrice.
  ///
  /// In en, this message translates to:
  /// **'39 kr / month'**
  String get paywallPrice;

  /// No description provided for @paywallUpgradeButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get paywallUpgradeButton;

  /// No description provided for @paywallRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get paywallRestoreButton;

  /// No description provided for @paywallDisclosure.
  ///
  /// In en, this message translates to:
  /// **'CruizX Pro · {price}/month · auto-renewing. Cancel anytime in Settings at least 24 hours before renewal. Charged to your Apple ID account.'**
  String paywallDisclosure(Object price);

  /// No description provided for @paywallDisclosureAndroid.
  ///
  /// In en, this message translates to:
  /// **'CruizX Pro · {price}/month · auto-renewing. Managed and billed via Stripe. Cancel anytime at cruizx.com or by contacting support.'**
  String paywallDisclosureAndroid(Object price);

  /// No description provided for @paywallFreeLabel.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get paywallFreeLabel;

  /// No description provided for @paywallProLabel.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get paywallProLabel;

  /// No description provided for @paywallFeatureRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes per day'**
  String get paywallFeatureRoutes;

  /// No description provided for @paywallFreeRouteLimit.
  ///
  /// In en, this message translates to:
  /// **'4 routes'**
  String get paywallFreeRouteLimit;

  /// No description provided for @paywallProRouteLimit.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get paywallProRouteLimit;

  /// No description provided for @paywallFeatureConvoy.
  ///
  /// In en, this message translates to:
  /// **'Convoy'**
  String get paywallFeatureConvoy;

  /// No description provided for @paywallFreeConvoyLimit.
  ///
  /// In en, this message translates to:
  /// **'1 active, 2 members'**
  String get paywallFreeConvoyLimit;

  /// No description provided for @paywallProConvoyLimit.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get paywallProConvoyLimit;

  /// No description provided for @paywallFeatureAds.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get paywallFeatureAds;

  /// No description provided for @paywallFreeAds.
  ///
  /// In en, this message translates to:
  /// **'Shown'**
  String get paywallFreeAds;

  /// No description provided for @paywallProAds.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get paywallProAds;

  /// No description provided for @paywallRouteLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Route limit reached'**
  String get paywallRouteLimitTitle;

  /// No description provided for @paywallRouteLimitBody.
  ///
  /// In en, this message translates to:
  /// **'Free users can calculate 4 routes per day. Upgrade to Pro for unlimited navigation.'**
  String get paywallRouteLimitBody;

  /// No description provided for @paywallConvoyLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Convoy limit reached'**
  String get paywallConvoyLimitTitle;

  /// No description provided for @paywallConvoyLimitBody.
  ///
  /// In en, this message translates to:
  /// **'Free users can only be in 1 convoy at a time.'**
  String get paywallConvoyLimitBody;

  /// No description provided for @paywallMemberLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Convoy is full'**
  String get paywallMemberLimitTitle;

  /// No description provided for @paywallMemberLimitBody.
  ///
  /// In en, this message translates to:
  /// **'Free users can only join convoys with fewer than 2 members. Upgrade to Pro for unlimited access.'**
  String get paywallMemberLimitBody;

  /// No description provided for @paywallPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'You are now a Pro user!'**
  String get paywallPurchaseSuccess;

  /// No description provided for @paywallPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase could not be completed. Please check your App Store account and try again.'**
  String get paywallPurchaseFailed;

  /// No description provided for @paywallRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchase restored!'**
  String get paywallRestoreSuccess;

  /// No description provided for @paywallLoginRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get paywallLoginRequiredTitle;

  /// No description provided for @paywallLoginRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'You need an account to purchase CruizX Pro. Create a free account in the app to continue.'**
  String get paywallLoginRequiredBody;

  /// No description provided for @paywallLoginRequiredAction.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get paywallLoginRequiredAction;

  /// No description provided for @paywallRestoreNotFound.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase found.'**
  String get paywallRestoreNotFound;

  /// No description provided for @profileFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get profileFreePlan;

  /// No description provided for @profileProPlan.
  ///
  /// In en, this message translates to:
  /// **'Pro plan'**
  String get profileProPlan;

  /// No description provided for @profileUpgradeToPro.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get profileUpgradeToPro;

  /// No description provided for @profileRoutesUsed.
  ///
  /// In en, this message translates to:
  /// **'Routes today: {count} / {max}'**
  String profileRoutesUsed(Object count, Object max);

  /// No description provided for @profileChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change profile photo'**
  String get profileChangePhoto;

  /// No description provided for @profileTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get profileTakePhoto;

  /// No description provided for @profileChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get profileChooseFromGallery;

  /// No description provided for @profilePhotoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload photo'**
  String get profilePhotoUploadFailed;

  /// No description provided for @parentModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Mode'**
  String get parentModeTitle;

  /// No description provided for @parentModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Let a parent follow your driving in real-time.'**
  String get parentModeDescription;

  /// No description provided for @parentModeLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to use Parent Mode.'**
  String get parentModeLoginRequired;

  /// No description provided for @parentModeEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Parent Mode'**
  String get parentModeEnable;

  /// No description provided for @parentModeEnabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Parents can follow your driving'**
  String get parentModeEnabledSubtitle;

  /// No description provided for @parentModeDisabledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No sharing active'**
  String get parentModeDisabledSubtitle;

  /// No description provided for @parentModeInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get parentModeInviteCode;

  /// No description provided for @parentModeInviteCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share this code with your parent to link their account.'**
  String get parentModeInviteCodeSubtitle;

  /// No description provided for @parentModeCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get parentModeCopyCode;

  /// No description provided for @parentModeShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get parentModeShareCode;

  /// No description provided for @parentModeCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied!'**
  String get parentModeCodeCopied;

  /// No description provided for @parentModeShareSubject.
  ///
  /// In en, this message translates to:
  /// **'CruizX Parent Code'**
  String get parentModeShareSubject;

  /// No description provided for @parentModeShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Hi! Use this code to follow my driving in CruizX: {code}'**
  String parentModeShareMessage(Object code);

  /// No description provided for @parentModeLinkedParents.
  ///
  /// In en, this message translates to:
  /// **'Linked Parents'**
  String get parentModeLinkedParents;

  /// No description provided for @parentModeNoParentsLinked.
  ///
  /// In en, this message translates to:
  /// **'No parents linked yet. Share your code!'**
  String get parentModeNoParentsLinked;

  /// No description provided for @parentModeUnlinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove parent?'**
  String get parentModeUnlinkTitle;

  /// No description provided for @parentModeUnlinkMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to remove {name} as a parent? They will no longer be able to follow your driving.'**
  String parentModeUnlinkMessage(Object name);

  /// No description provided for @parentModeUnlink.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get parentModeUnlink;

  /// No description provided for @parentModeShareSettings.
  ///
  /// In en, this message translates to:
  /// **'What to share'**
  String get parentModeShareSettings;

  /// No description provided for @parentModeShareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share location'**
  String get parentModeShareLocation;

  /// No description provided for @parentModeShareLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show where you are on the map'**
  String get parentModeShareLocationSubtitle;

  /// No description provided for @parentModeShareSpeed.
  ///
  /// In en, this message translates to:
  /// **'Share speed'**
  String get parentModeShareSpeed;

  /// No description provided for @parentModeShareSpeedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show your current speed'**
  String get parentModeShareSpeedSubtitle;

  /// No description provided for @parentModeAlertSettings.
  ///
  /// In en, this message translates to:
  /// **'Notifications to parents'**
  String get parentModeAlertSettings;

  /// No description provided for @parentModeSpeedAlert.
  ///
  /// In en, this message translates to:
  /// **'Speed alert'**
  String get parentModeSpeedAlert;

  /// No description provided for @parentModeSpeedAlertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notify when speed exceeds {limit} km/h'**
  String parentModeSpeedAlertSubtitle(Object limit);

  /// No description provided for @parentModeSpeedLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get parentModeSpeedLimit;

  /// No description provided for @parentModeNightAlert.
  ///
  /// In en, this message translates to:
  /// **'Night driving alert'**
  String get parentModeNightAlert;

  /// No description provided for @parentModeNightAlertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notify when driving between {start}–{end}'**
  String parentModeNightAlertSubtitle(Object start, Object end);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @parentDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent Dashboard'**
  String get parentDashboardTitle;

  /// No description provided for @parentDashboardMapTab.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get parentDashboardMapTab;

  /// No description provided for @parentDashboardAlertsTab.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get parentDashboardAlertsTab;

  /// No description provided for @parentDashboardAddChild.
  ///
  /// In en, this message translates to:
  /// **'Add child'**
  String get parentDashboardAddChild;

  /// No description provided for @parentDashboardOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get parentDashboardOnline;

  /// No description provided for @parentDashboardOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get parentDashboardOffline;

  /// No description provided for @parentDashboardNoAlerts.
  ///
  /// In en, this message translates to:
  /// **'No alerts in the last 24 hours'**
  String get parentDashboardNoAlerts;

  /// No description provided for @parentDashboardNoChildren.
  ///
  /// In en, this message translates to:
  /// **'No children linked yet'**
  String get parentDashboardNoChildren;

  /// No description provided for @parentDashboardNoChildrenHint.
  ///
  /// In en, this message translates to:
  /// **'Add a child by entering their invite code from CruizX Parent Mode.'**
  String get parentDashboardNoChildrenHint;

  /// No description provided for @parentDashboardEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code'**
  String get parentDashboardEnterCode;

  /// No description provided for @parentDashboardEnterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Ask your child to share their 6-character invite code from Parent Mode settings.'**
  String get parentDashboardEnterCodeHint;

  /// No description provided for @parentDashboardLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get parentDashboardLink;

  /// No description provided for @parentDashboardLinkSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully linked!'**
  String get parentDashboardLinkSuccess;

  /// No description provided for @parentDashboardLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not find child with that code. Check the code and try again.'**
  String get parentDashboardLinkFailed;

  /// No description provided for @parentDashboardLinkSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot link to your own account. Ask your child to share their code from their account.'**
  String get parentDashboardLinkSelf;

  /// No description provided for @parentDashboardSpeedingAlert.
  ///
  /// In en, this message translates to:
  /// **'Speed alert'**
  String get parentDashboardSpeedingAlert;

  /// No description provided for @parentDashboardSpeedingDetail.
  ///
  /// In en, this message translates to:
  /// **'{name} drove at {speed} km/h (limit: {limit} km/h)'**
  String parentDashboardSpeedingDetail(Object name, Object speed, Object limit);

  /// No description provided for @parentDashboardNightAlert.
  ///
  /// In en, this message translates to:
  /// **'Night driving'**
  String get parentDashboardNightAlert;

  /// No description provided for @parentDashboardNightDetail.
  ///
  /// In en, this message translates to:
  /// **'{name} is driving at night'**
  String parentDashboardNightDetail(Object name);

  /// No description provided for @parentDashboardViewChild.
  ///
  /// In en, this message translates to:
  /// **'View as parent'**
  String get parentDashboardViewChild;

  /// No description provided for @settingsVoiceNavigation.
  ///
  /// In en, this message translates to:
  /// **'Voice navigation'**
  String get settingsVoiceNavigation;

  /// No description provided for @settingsVoiceNavigationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read turn instructions aloud'**
  String get settingsVoiceNavigationSubtitle;

  /// No description provided for @settingsMapMarkerLabel.
  ///
  /// In en, this message translates to:
  /// **'Map marker'**
  String get settingsMapMarkerLabel;

  /// No description provided for @settingsMapMarkerArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get settingsMapMarkerArrow;

  /// No description provided for @settingsMapMarkerCompass.
  ///
  /// In en, this message translates to:
  /// **'Compass'**
  String get settingsMapMarkerCompass;

  /// No description provided for @settingsMapMarkerTriangle.
  ///
  /// In en, this message translates to:
  /// **'Triangle'**
  String get settingsMapMarkerTriangle;

  /// No description provided for @settingsMapMarkerDot.
  ///
  /// In en, this message translates to:
  /// **'Dot'**
  String get settingsMapMarkerDot;

  /// No description provided for @settingsMapMarkerCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get settingsMapMarkerCar;

  /// No description provided for @settingsMapMarkerEpa.
  ///
  /// In en, this message translates to:
  /// **'EPA'**
  String get settingsMapMarkerEpa;

  /// No description provided for @settingsMapMarkerMicrocar.
  ///
  /// In en, this message translates to:
  /// **'Microcar'**
  String get settingsMapMarkerMicrocar;

  /// No description provided for @settingsMapMarkerSmile.
  ///
  /// In en, this message translates to:
  /// **'Smile'**
  String get settingsMapMarkerSmile;

  /// No description provided for @settingsMapMarkerCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get settingsMapMarkerCool;

  /// No description provided for @settingsMapMarkerTurbo.
  ///
  /// In en, this message translates to:
  /// **'Turbo'**
  String get settingsMapMarkerTurbo;

  /// No description provided for @settingsMapMarkerCrown.
  ///
  /// In en, this message translates to:
  /// **'Crown'**
  String get settingsMapMarkerCrown;

  /// No description provided for @settingsMapMarkerGhost.
  ///
  /// In en, this message translates to:
  /// **'Ghost'**
  String get settingsMapMarkerGhost;

  /// No description provided for @voiceTurnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left'**
  String get voiceTurnLeft;

  /// No description provided for @voiceTurnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right'**
  String get voiceTurnRight;

  /// No description provided for @voiceTurnSharpLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn sharp left'**
  String get voiceTurnSharpLeft;

  /// No description provided for @voiceTurnSharpRight.
  ///
  /// In en, this message translates to:
  /// **'Turn sharp right'**
  String get voiceTurnSharpRight;

  /// No description provided for @voiceTurnSlightLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn slight left'**
  String get voiceTurnSlightLeft;

  /// No description provided for @voiceTurnSlightRight.
  ///
  /// In en, this message translates to:
  /// **'Turn slight right'**
  String get voiceTurnSlightRight;

  /// No description provided for @voiceContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue straight'**
  String get voiceContinue;

  /// No description provided for @voiceRoundabout.
  ///
  /// In en, this message translates to:
  /// **'Enter the roundabout'**
  String get voiceRoundabout;

  /// No description provided for @voiceDestination.
  ///
  /// In en, this message translates to:
  /// **'You have reached your destination'**
  String get voiceDestination;

  /// No description provided for @voiceInMeters.
  ///
  /// In en, this message translates to:
  /// **'In {meters} meters'**
  String voiceInMeters(Object meters);

  /// No description provided for @voiceInKm.
  ///
  /// In en, this message translates to:
  /// **'In {km} kilometers'**
  String voiceInKm(Object km);

  /// No description provided for @mfaSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable two-factor authentication'**
  String get mfaSetupTitle;

  /// No description provided for @mfaSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code with an authenticator app like Google Authenticator or Authy'**
  String get mfaSetupSubtitle;

  /// No description provided for @mfaScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan the code above and enter the 6-digit code below'**
  String get mfaScanQr;

  /// No description provided for @mfaVerifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get mfaVerifyButton;

  /// No description provided for @mfaVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get mfaVerifyTitle;

  /// No description provided for @mfaVerifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app'**
  String get mfaVerifySubtitle;

  /// No description provided for @mfaInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code, try again'**
  String get mfaInvalidCode;

  /// No description provided for @mfaCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel and sign out'**
  String get mfaCancel;

  /// No description provided for @mfaProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get mfaProfileTitle;

  /// No description provided for @mfaStatusOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled — your account is protected'**
  String get mfaStatusOn;

  /// No description provided for @mfaStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get mfaStatusOff;

  /// No description provided for @mfaTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get mfaTurnOn;

  /// No description provided for @mfaTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get mfaTurnOff;

  /// No description provided for @mfaDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off 2FA?'**
  String get mfaDisableTitle;

  /// No description provided for @mfaDisableBody.
  ///
  /// In en, this message translates to:
  /// **'Your account will be less secure without two-factor authentication.'**
  String get mfaDisableBody;

  /// No description provided for @mfaDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get mfaDisableConfirm;

  /// No description provided for @mfaShowManualKey.
  ///
  /// In en, this message translates to:
  /// **'Can\'t scan? Show key manually'**
  String get mfaShowManualKey;

  /// No description provided for @mfaHideManualKey.
  ///
  /// In en, this message translates to:
  /// **'Hide manual key'**
  String get mfaHideManualKey;

  /// No description provided for @mfaKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Key copied'**
  String get mfaKeyCopied;

  /// No description provided for @mfaRecommendTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your account'**
  String get mfaRecommendTitle;

  /// No description provided for @mfaRecommendBody.
  ///
  /// In en, this message translates to:
  /// **'We recommend enabling two-factor authentication to protect your account. You can use an authenticator app like Google Authenticator or Authy.'**
  String get mfaRecommendBody;

  /// No description provided for @mfaRecommendSetup.
  ///
  /// In en, this message translates to:
  /// **'Enable now'**
  String get mfaRecommendSetup;

  /// No description provided for @mfaRecommendLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get mfaRecommendLater;

  /// No description provided for @favHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get favHome;

  /// No description provided for @favSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get favSchool;

  /// No description provided for @favWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get favWork;

  /// No description provided for @favAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Save place'**
  String get favAddTitle;

  /// No description provided for @favLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Name (e.g. Friend)'**
  String get favLabelHint;

  /// No description provided for @favSaved.
  ///
  /// In en, this message translates to:
  /// **'Place saved'**
  String get favSaved;

  /// No description provided for @favDeleted.
  ///
  /// In en, this message translates to:
  /// **'Place removed'**
  String get favDeleted;

  /// No description provided for @favDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String favDeleteConfirm(Object name);

  /// No description provided for @favSetAs.
  ///
  /// In en, this message translates to:
  /// **'Save as {type}'**
  String favSetAs(Object type);

  /// No description provided for @favCustom.
  ///
  /// In en, this message translates to:
  /// **'Other favorite'**
  String get favCustom;

  /// No description provided for @ttsVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Tip: Download better voices in Settings → Accessibility → Spoken Content → Voices'**
  String get ttsVoiceHint;

  /// No description provided for @ttsVoiceHintDismiss.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ttsVoiceHintDismiss;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'da',
    'en',
    'es',
    'fi',
    'fr',
    'nb',
    'sv',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'da':
      return AppLocalizationsDa();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fi':
      return AppLocalizationsFi();
    case 'fr':
      return AppLocalizationsFr();
    case 'nb':
      return AppLocalizationsNb();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
