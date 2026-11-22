import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_rw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('en'),
    Locale('fr'),
    Locale('rw')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Mpuza - Rwanda'**
  String get appTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @continueToLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue to Login'**
  String get continueToLogin;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKinyarwanda.
  ///
  /// In en, this message translates to:
  /// **'Kinyarwanda'**
  String get languageKinyarwanda;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change language: {error}'**
  String languageUpdateFailed(String error);

  /// No description provided for @openNavigationMenu.
  ///
  /// In en, this message translates to:
  /// **'Open navigation menu'**
  String get openNavigationMenu;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get collapseSidebar;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @textTranslation.
  ///
  /// In en, this message translates to:
  /// **'Text Translation'**
  String get textTranslation;

  /// No description provided for @speechTranslation.
  ///
  /// In en, this message translates to:
  /// **'Speech Translation'**
  String get speechTranslation;

  /// No description provided for @videoTranslation.
  ///
  /// In en, this message translates to:
  /// **'Video Translation'**
  String get videoTranslation;

  /// No description provided for @cameraTranslation.
  ///
  /// In en, this message translates to:
  /// **'Camera Translation'**
  String get cameraTranslation;

  /// No description provided for @startTranslating.
  ///
  /// In en, this message translates to:
  /// **'Start Translating'**
  String get startTranslating;

  /// No description provided for @educationTools.
  ///
  /// In en, this message translates to:
  /// **'Education Tools'**
  String get educationTools;

  /// No description provided for @underDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Under Development'**
  String get underDevelopment;

  /// No description provided for @offlinePacks.
  ///
  /// In en, this message translates to:
  /// **'Offline Packs'**
  String get offlinePacks;

  /// No description provided for @driverMode.
  ///
  /// In en, this message translates to:
  /// **'Driver Mode'**
  String get driverMode;

  /// No description provided for @googleMaps.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get googleMaps;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutBlurb.
  ///
  /// In en, this message translates to:
  /// **'Breaking language barriers in Rwanda, Africa & World.'**
  String get aboutBlurb;

  /// No description provided for @supportedLanguages.
  ///
  /// In en, this message translates to:
  /// **'Supporting Kinyarwanda, English, and French.'**
  String get supportedLanguages;

  /// No description provided for @madeWithPride.
  ///
  /// In en, this message translates to:
  /// **'🇷🇼 Made with pride in Rwanda 🇷🇼'**
  String get madeWithPride;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get version;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get settingsTitle;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @enableDarkTheme.
  ///
  /// In en, this message translates to:
  /// **'Enable dark theme'**
  String get enableDarkTheme;

  /// No description provided for @defaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default Language'**
  String get defaultLanguage;

  /// No description provided for @speechRate.
  ///
  /// In en, this message translates to:
  /// **'Speech Rate'**
  String get speechRate;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @cacheUsage.
  ///
  /// In en, this message translates to:
  /// **'{size} used'**
  String cacheUsage(String size);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @loginToContinue.
  ///
  /// In en, this message translates to:
  /// **'Log in to continue translating.'**
  String get loginToContinue;

  /// No description provided for @emailOrUsername.
  ///
  /// In en, this message translates to:
  /// **'Email or username'**
  String get emailOrUsername;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @newToMpuza.
  ///
  /// In en, this message translates to:
  /// **'New to MPUZA? '**
  String get newToMpuza;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signupStepOne.
  ///
  /// In en, this message translates to:
  /// **'STEP 1 OF 2'**
  String get signupStepOne;

  /// No description provided for @joinMpuza.
  ///
  /// In en, this message translates to:
  /// **'Join MPUZA and start translating across languages.'**
  String get joinMpuza;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @invalidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get invalidEmailAddress;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @signupStepTwo.
  ///
  /// In en, this message translates to:
  /// **'STEP 2 OF 2'**
  String get signupStepTwo;

  /// No description provided for @aboutYouAndSecurity.
  ///
  /// In en, this message translates to:
  /// **'About you & security'**
  String get aboutYouAndSecurity;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get preferNotToSay;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @countryRwanda.
  ///
  /// In en, this message translates to:
  /// **'Rwanda'**
  String get countryRwanda;

  /// No description provided for @countryBurundi.
  ///
  /// In en, this message translates to:
  /// **'Burundi'**
  String get countryBurundi;

  /// No description provided for @countryDrCongo.
  ///
  /// In en, this message translates to:
  /// **'Democratic Republic of the Congo'**
  String get countryDrCongo;

  /// No description provided for @countryKenya.
  ///
  /// In en, this message translates to:
  /// **'Kenya'**
  String get countryKenya;

  /// No description provided for @countryTanzania.
  ///
  /// In en, this message translates to:
  /// **'Tanzania'**
  String get countryTanzania;

  /// No description provided for @countryUganda.
  ///
  /// In en, this message translates to:
  /// **'Uganda'**
  String get countryUganda;

  /// No description provided for @createStrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Create a strong password'**
  String get createStrongPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @reenterPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get reenterPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordsMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords match'**
  String get passwordsMatch;

  /// No description provided for @verifyYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyYourEmail;

  /// No description provided for @verificationCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to\n{email}'**
  String verificationCodeSentTo(String email);

  /// No description provided for @codeExpiresInPrefix.
  ///
  /// In en, this message translates to:
  /// **'Code expires in '**
  String get codeExpiresInPrefix;

  /// No description provided for @didntGetIt.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get it? '**
  String get didntGetIt;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {duration}'**
  String resendIn(String duration);

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @wrongEmail.
  ///
  /// In en, this message translates to:
  /// **'Wrong email? '**
  String get wrongEmail;

  /// No description provided for @changeIt.
  ///
  /// In en, this message translates to:
  /// **'Change it'**
  String get changeIt;

  /// No description provided for @emailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified!'**
  String get emailVerified;

  /// No description provided for @accountReadyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your MPUZA account is ready. Log in with your email or username to start translating.'**
  String get accountReadyMessage;

  /// No description provided for @goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get goToLogin;

  /// No description provided for @forgotPasswordInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the email address linked to your MPUZA account. We will send you a reset code.'**
  String get forgotPasswordInstructions;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get sendResetCode;

  /// No description provided for @rememberPassword.
  ///
  /// In en, this message translates to:
  /// **'Remember your password? '**
  String get rememberPassword;

  /// No description provided for @resetYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetYourPassword;

  /// No description provided for @resetCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to\n{email}'**
  String resetCodeSentTo(String email);

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @weak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get weak;

  /// No description provided for @fair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get fair;

  /// No description provided for @strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strong;

  /// No description provided for @passwordStrength.
  ///
  /// In en, this message translates to:
  /// **'Password strength'**
  String get passwordStrength;

  /// No description provided for @eightPlusCharacters.
  ///
  /// In en, this message translates to:
  /// **'8+ characters'**
  String get eightPlusCharacters;

  /// No description provided for @uppercase.
  ///
  /// In en, this message translates to:
  /// **'Uppercase'**
  String get uppercase;

  /// No description provided for @lowercase.
  ///
  /// In en, this message translates to:
  /// **'Lowercase'**
  String get lowercase;

  /// No description provided for @numberAndSymbol.
  ///
  /// In en, this message translates to:
  /// **'Number & symbol'**
  String get numberAndSymbol;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// No description provided for @passwordStrengthRequirement.
  ///
  /// In en, this message translates to:
  /// **'Use 8+ characters with uppercase, lowercase, a number and a symbol'**
  String get passwordStrengthRequirement;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select a gender option to continue.'**
  String get selectGender;

  /// No description provided for @enterSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code to continue.'**
  String get enterSixDigitCode;

  /// No description provided for @passwordResetComplete.
  ///
  /// In en, this message translates to:
  /// **'Password reset. You can now log in.'**
  String get passwordResetComplete;

  /// No description provided for @translationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Translation successful'**
  String get translationSuccessful;

  /// No description provided for @translationTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Translation is taking longer than expected. Please try again.'**
  String get translationTimedOut;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed: {error}'**
  String translationFailed(String error);

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard!'**
  String get copiedToClipboard;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites!'**
  String get removedFromFavorites;

  /// No description provided for @savedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Saved to favorites!'**
  String get savedToFavorites;

  /// No description provided for @sourceText.
  ///
  /// In en, this message translates to:
  /// **'Source Text'**
  String get sourceText;

  /// No description provided for @sourceTextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text to translate...'**
  String get sourceTextHint;

  /// No description provided for @characterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String characterCount(int count);

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating...'**
  String get translating;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// No description provided for @translation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translation;

  /// No description provided for @translationPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Translation will appear here'**
  String get translationPlaceholder;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission required'**
  String get cameraPermissionRequired;

  /// No description provided for @noTextFoundInImage.
  ///
  /// In en, this message translates to:
  /// **'No text found in image'**
  String get noTextFoundInImage;

  /// No description provided for @imageProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Error processing image: {error}'**
  String imageProcessingFailed(String error);

  /// No description provided for @imageTranslationFailed.
  ///
  /// In en, this message translates to:
  /// **'Error translating text: {error}'**
  String imageTranslationFailed(String error);

  /// No description provided for @takeOrUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Take or Upload Image'**
  String get takeOrUploadImage;

  /// No description provided for @takeRearPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo (Rear)'**
  String get takeRearPhoto;

  /// No description provided for @takeFrontPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo (Front)'**
  String get takeFrontPhoto;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// No description provided for @offlineTranslationPacks.
  ///
  /// In en, this message translates to:
  /// **'Offline Translation Packs'**
  String get offlineTranslationPacks;

  /// No description provided for @deviceStorage.
  ///
  /// In en, this message translates to:
  /// **'Device Storage'**
  String get deviceStorage;

  /// No description provided for @storageUsage.
  ///
  /// In en, this message translates to:
  /// **'{used} used • {free} free'**
  String storageUsage(String used, String free);

  /// No description provided for @myPacks.
  ///
  /// In en, this message translates to:
  /// **'My Packs'**
  String get myPacks;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadingPack.
  ///
  /// In en, this message translates to:
  /// **'Downloading {pack}...'**
  String downloadingPack(String pack);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @basicKinyarwandaPack.
  ///
  /// In en, this message translates to:
  /// **'Basic Kinyarwanda Pack'**
  String get basicKinyarwandaPack;

  /// No description provided for @essentialPhrasesDescription.
  ///
  /// In en, this message translates to:
  /// **'Essential phrases and common vocabulary'**
  String get essentialPhrasesDescription;

  /// No description provided for @completeKinyarwandaPack.
  ///
  /// In en, this message translates to:
  /// **'Complete Kinyarwanda Pack'**
  String get completeKinyarwandaPack;

  /// No description provided for @completeDictionaryDescription.
  ///
  /// In en, this message translates to:
  /// **'Full Kinyarwanda-English-French dictionary'**
  String get completeDictionaryDescription;

  /// No description provided for @motoristCommunicationPack.
  ///
  /// In en, this message translates to:
  /// **'Motorist Communication Pack'**
  String get motoristCommunicationPack;

  /// No description provided for @transportationPhrasesDescription.
  ///
  /// In en, this message translates to:
  /// **'Transportation and navigation phrases'**
  String get transportationPhrasesDescription;

  /// No description provided for @medicalEmergencyPack.
  ///
  /// In en, this message translates to:
  /// **'Medical & Emergency Pack'**
  String get medicalEmergencyPack;

  /// No description provided for @healthcareVocabularyDescription.
  ///
  /// In en, this message translates to:
  /// **'Healthcare and emergency vocabulary'**
  String get healthcareVocabularyDescription;

  /// No description provided for @educationPack.
  ///
  /// In en, this message translates to:
  /// **'Education Pack'**
  String get educationPack;

  /// No description provided for @academicVocabularyDescription.
  ///
  /// In en, this message translates to:
  /// **'Academic vocabulary and terminology'**
  String get academicVocabularyDescription;

  /// No description provided for @tourismHospitalityPack.
  ///
  /// In en, this message translates to:
  /// **'Tourism & Hospitality Pack'**
  String get tourismHospitalityPack;

  /// No description provided for @tourismPhrasesDescription.
  ///
  /// In en, this message translates to:
  /// **'Tourist phrases and service vocabulary'**
  String get tourismPhrasesDescription;

  /// No description provided for @lectureSummarizer.
  ///
  /// In en, this message translates to:
  /// **'Lecture Summarizer'**
  String get lectureSummarizer;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon!'**
  String get comingSoon;

  /// No description provided for @autoSummarizeLectures.
  ///
  /// In en, this message translates to:
  /// **'Auto-summarization of lectures'**
  String get autoSummarizeLectures;

  /// No description provided for @studyNotesGeneration.
  ///
  /// In en, this message translates to:
  /// **'Study notes generation'**
  String get studyNotesGeneration;

  /// No description provided for @vocabularyExtraction.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary extraction'**
  String get vocabularyExtraction;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @motoristModeActive.
  ///
  /// In en, this message translates to:
  /// **'Motorist Mode Active'**
  String get motoristModeActive;

  /// No description provided for @listeningForCommands.
  ///
  /// In en, this message translates to:
  /// **'Listening for commands...'**
  String get listeningForCommands;

  /// No description provided for @tapToActivate.
  ///
  /// In en, this message translates to:
  /// **'Tap to activate'**
  String get tapToActivate;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @fare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fare;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @currentlyNavigating.
  ///
  /// In en, this message translates to:
  /// **'Currently navigating'**
  String get currentlyNavigating;

  /// No description provided for @readyForPassengers.
  ///
  /// In en, this message translates to:
  /// **'Ready for passengers'**
  String get readyForPassengers;

  /// No description provided for @followTheRoute.
  ///
  /// In en, this message translates to:
  /// **'Follow the route'**
  String get followTheRoute;

  /// No description provided for @tapToStartNavigation.
  ///
  /// In en, this message translates to:
  /// **'Tap to start navigation'**
  String get tapToStartNavigation;

  /// No description provided for @voiceCommands.
  ///
  /// In en, this message translates to:
  /// **'Voice Commands'**
  String get voiceCommands;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get listening;

  /// No description provided for @tapToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap to speak'**
  String get tapToSpeak;

  /// No description provided for @enableLocationServices.
  ///
  /// In en, this message translates to:
  /// **'Please enable location services'**
  String get enableLocationServices;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permissions permanently denied'**
  String get locationPermissionPermanentlyDenied;

  /// No description provided for @showingKigaliCenter.
  ///
  /// In en, this message translates to:
  /// **'Showing Kigali Center'**
  String get showingKigaliCenter;

  /// No description provided for @placeSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Please try again.'**
  String get placeSearchFailed;

  /// No description provided for @noPhoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'No phone available'**
  String get noPhoneAvailable;

  /// No description provided for @placeCategory.
  ///
  /// In en, this message translates to:
  /// **'{category}'**
  String placeCategory(String category);

  /// No description provided for @freeGeocodingNoApiKey.
  ///
  /// In en, this message translates to:
  /// **'Free geocoding - no API key'**
  String get freeGeocodingNoApiKey;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @navigateHere.
  ///
  /// In en, this message translates to:
  /// **'Navigate Here'**
  String get navigateHere;

  /// No description provided for @selectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected Location'**
  String get selectedLocation;

  /// No description provided for @setDestinationFirst.
  ///
  /// In en, this message translates to:
  /// **'Please set a destination first'**
  String get setDestinationFirst;

  /// No description provided for @headDirection.
  ///
  /// In en, this message translates to:
  /// **'Head {direction}'**
  String headDirection(String direction);

  /// No description provided for @north.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get north;

  /// No description provided for @south.
  ///
  /// In en, this message translates to:
  /// **'South'**
  String get south;

  /// No description provided for @east.
  ///
  /// In en, this message translates to:
  /// **'East'**
  String get east;

  /// No description provided for @west.
  ///
  /// In en, this message translates to:
  /// **'West'**
  String get west;

  /// No description provided for @northeast.
  ///
  /// In en, this message translates to:
  /// **'Northeast'**
  String get northeast;

  /// No description provided for @northwest.
  ///
  /// In en, this message translates to:
  /// **'Northwest'**
  String get northwest;

  /// No description provided for @southeast.
  ///
  /// In en, this message translates to:
  /// **'Southeast'**
  String get southeast;

  /// No description provided for @southwest.
  ///
  /// In en, this message translates to:
  /// **'Southwest'**
  String get southwest;

  /// No description provided for @offlineDirectRoute.
  ///
  /// In en, this message translates to:
  /// **'Offline route (direct line)'**
  String get offlineDirectRoute;

  /// No description provided for @freeMapsRwanda.
  ///
  /// In en, this message translates to:
  /// **'🗺️ Free Maps - Rwanda'**
  String get freeMapsRwanda;

  /// No description provided for @liveLocationFreeGeocoding.
  ///
  /// In en, this message translates to:
  /// **'Live location • free geocoding'**
  String get liveLocationFreeGeocoding;

  /// No description provided for @hideNearbyPlaces.
  ///
  /// In en, this message translates to:
  /// **'Hide Nearby Places'**
  String get hideNearbyPlaces;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My Location'**
  String get myLocation;

  /// No description provided for @gettingLiveLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting your live location...'**
  String get gettingLiveLocation;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get zoomOut;

  /// No description provided for @searchPlaceHint.
  ///
  /// In en, this message translates to:
  /// **'Search any place in Rwanda...'**
  String get searchPlaceHint;

  /// No description provided for @nearbyPlaces.
  ///
  /// In en, this message translates to:
  /// **'Nearby Places'**
  String get nearbyPlaces;

  /// No description provided for @bestRoute.
  ///
  /// In en, this message translates to:
  /// **'Best Route'**
  String get bestRoute;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @minutesAbbreviation.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesAbbreviation(String minutes);

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @travelMode.
  ///
  /// In en, this message translates to:
  /// **'Travel Mode'**
  String get travelMode;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @routeReady.
  ///
  /// In en, this message translates to:
  /// **'Route ready'**
  String get routeReady;

  /// No description provided for @setDestination.
  ///
  /// In en, this message translates to:
  /// **'Set Destination'**
  String get setDestination;

  /// No description provided for @getDirections.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get getDirections;

  /// No description provided for @clearRoute.
  ///
  /// In en, this message translates to:
  /// **'Clear Route'**
  String get clearRoute;

  /// No description provided for @hospitals.
  ///
  /// In en, this message translates to:
  /// **'Hospitals'**
  String get hospitals;

  /// No description provided for @hotels.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get hotels;

  /// No description provided for @restaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get restaurants;

  /// No description provided for @coffeeShops.
  ///
  /// In en, this message translates to:
  /// **'Coffee Shops'**
  String get coffeeShops;

  /// No description provided for @bars.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get bars;

  /// No description provided for @car.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get car;

  /// No description provided for @walk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walk;

  /// No description provided for @bicycle.
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get bicycle;

  /// No description provided for @microphonePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to use speech recognition'**
  String get microphonePermissionRequired;

  /// No description provided for @noSpeechDetected.
  ///
  /// In en, this message translates to:
  /// **'No speech detected. Speak clearly and try again.'**
  String get noSpeechDetected;

  /// No description provided for @microphonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get microphonePermissionDenied;

  /// No description provided for @speechRecognitionError.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition error'**
  String get speechRecognitionError;

  /// No description provided for @speechRecognitionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is not available. Please allow microphone access and try again.'**
  String get speechRecognitionUnavailable;

  /// No description provided for @couldNotStartListening.
  ///
  /// In en, this message translates to:
  /// **'Could not start listening. Please allow microphone access and try again.'**
  String get couldNotStartListening;

  /// No description provided for @browserMicrophonePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required: use the lock icon in your browser address bar to allow microphone access.'**
  String get browserMicrophonePermissionRequired;

  /// No description provided for @noMicrophoneDetected.
  ///
  /// In en, this message translates to:
  /// **'No microphone detected. Please connect a microphone.'**
  String get noMicrophoneDetected;

  /// No description provided for @microphoneReady.
  ///
  /// In en, this message translates to:
  /// **'Microphone ready. Speak clearly now.'**
  String get microphoneReady;

  /// No description provided for @couldNotStartListeningWithError.
  ///
  /// In en, this message translates to:
  /// **'Could not start listening. Error: {error}'**
  String couldNotStartListeningWithError(String error);

  /// No description provided for @audioSelected.
  ///
  /// In en, this message translates to:
  /// **'Audio selected: {fileName}'**
  String audioSelected(String fileName);

  /// No description provided for @audioTranscribed.
  ///
  /// In en, this message translates to:
  /// **'Audio transcribed successfully!'**
  String get audioTranscribed;

  /// No description provided for @audioSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Error picking audio: {error}'**
  String audioSelectionFailed(String error);

  /// No description provided for @selectedAudioCouldNotBeRead.
  ///
  /// In en, this message translates to:
  /// **'The selected audio file could not be read.'**
  String get selectedAudioCouldNotBeRead;

  /// No description provided for @emptySpeechTranslationResponse.
  ///
  /// In en, this message translates to:
  /// **'The speech translation response was empty.'**
  String get emptySpeechTranslationResponse;

  /// No description provided for @translationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Translation completed'**
  String get translationCompleted;

  /// No description provided for @recordVoice.
  ///
  /// In en, this message translates to:
  /// **'Record Voice'**
  String get recordVoice;

  /// No description provided for @uploadAudio.
  ///
  /// In en, this message translates to:
  /// **'Upload Audio'**
  String get uploadAudio;

  /// No description provided for @fromLanguage.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLanguage;

  /// No description provided for @toLanguage.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toLanguage;

  /// No description provided for @outputOptions.
  ///
  /// In en, this message translates to:
  /// **'Output Options:'**
  String get outputOptions;

  /// No description provided for @textOutput.
  ///
  /// In en, this message translates to:
  /// **'📝 Text'**
  String get textOutput;

  /// No description provided for @audioOutput.
  ///
  /// In en, this message translates to:
  /// **'🔊 Audio'**
  String get audioOutput;

  /// No description provided for @bothOutputs.
  ///
  /// In en, this message translates to:
  /// **'📝🔊 Both'**
  String get bothOutputs;

  /// No description provided for @processingAudio.
  ///
  /// In en, this message translates to:
  /// **'Processing Audio...'**
  String get processingAudio;

  /// No description provided for @convertingSpeechToText.
  ///
  /// In en, this message translates to:
  /// **'Converting speech to text'**
  String get convertingSpeechToText;

  /// No description provided for @tapToStartRecording.
  ///
  /// In en, this message translates to:
  /// **'Tap to start recording'**
  String get tapToStartRecording;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {percentage}%'**
  String confidence(String percentage);

  /// No description provided for @recognizedSpeech.
  ///
  /// In en, this message translates to:
  /// **'Recognized Speech'**
  String get recognizedSpeech;

  /// No description provided for @shareComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Share feature coming soon!'**
  String get shareComingSoon;

  /// No description provided for @recentTranslations.
  ///
  /// In en, this message translates to:
  /// **'Recent Translations'**
  String get recentTranslations;

  /// No description provided for @liveTranslationTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Live translation timed out. Please try again with a shorter video.'**
  String get liveTranslationTimedOut;

  /// No description provided for @mediaPermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera or microphone access is permanently denied. Please enable it in app settings.'**
  String get mediaPermissionPermanentlyDenied;

  /// No description provided for @cameraMicrophonePermissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera and microphone permissions are required to record video.'**
  String get cameraMicrophonePermissionsRequired;

  /// No description provided for @chooseVideoSource.
  ///
  /// In en, this message translates to:
  /// **'Choose how to provide your video'**
  String get chooseVideoSource;

  /// No description provided for @recordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record video'**
  String get recordVideo;

  /// No description provided for @recordVideoDescription.
  ///
  /// In en, this message translates to:
  /// **'Use your camera to capture a new video'**
  String get recordVideoDescription;

  /// No description provided for @uploadVideoFromStorage.
  ///
  /// In en, this message translates to:
  /// **'Upload video from local storage'**
  String get uploadVideoFromStorage;

  /// No description provided for @pickVideoDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick a video file from your device'**
  String get pickVideoDescription;

  /// No description provided for @noVideoSelected.
  ///
  /// In en, this message translates to:
  /// **'No video file was selected.'**
  String get noVideoSelected;

  /// No description provided for @videoSelected.
  ///
  /// In en, this message translates to:
  /// **'Video selected: {filename}'**
  String videoSelected(String filename);

  /// No description provided for @videoPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to pick the video file: {error}'**
  String videoPickFailed(String error);

  /// No description provided for @noVideoRecorded.
  ///
  /// In en, this message translates to:
  /// **'No video was recorded.'**
  String get noVideoRecorded;

  /// No description provided for @videoRecorded.
  ///
  /// In en, this message translates to:
  /// **'Video recorded: {filename}'**
  String videoRecorded(String filename);

  /// No description provided for @videoRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to record the video: {error}'**
  String videoRecordFailed(String error);

  /// No description provided for @noMediaSelected.
  ///
  /// In en, this message translates to:
  /// **'No media selected'**
  String get noMediaSelected;

  /// No description provided for @preparingLiveSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Preparing live translated subtitles...'**
  String get preparingLiveSubtitles;

  /// No description provided for @invalidTranslationResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response format from translation service.'**
  String get invalidTranslationResponse;

  /// No description provided for @translationComplete.
  ///
  /// In en, this message translates to:
  /// **'Translation complete!'**
  String get translationComplete;

  /// No description provided for @mediaUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Media upload failed: {error}'**
  String mediaUploadFailed(String error);

  /// No description provided for @enterYoutubeUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a YouTube URL'**
  String get enterYoutubeUrl;

  /// No description provided for @youtubeLiveTranslationFailed.
  ///
  /// In en, this message translates to:
  /// **'YouTube live translation failed'**
  String get youtubeLiveTranslationFailed;

  /// No description provided for @youtubeLiveTranslationFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'YouTube live translation failed: {error}'**
  String youtubeLiveTranslationFailedWithError(String error);

  /// No description provided for @noSpokenPhrasesDetected.
  ///
  /// In en, this message translates to:
  /// **'No spoken phrases were detected.'**
  String get noSpokenPhrasesDetected;

  /// No description provided for @liveSubtitlesReady.
  ///
  /// In en, this message translates to:
  /// **'Live subtitles ready.'**
  String get liveSubtitlesReady;

  /// No description provided for @liveTranslationFailed.
  ///
  /// In en, this message translates to:
  /// **'Live translation failed'**
  String get liveTranslationFailed;

  /// No description provided for @emptyMediaSummaryResponse.
  ///
  /// In en, this message translates to:
  /// **'The media summary response was empty.'**
  String get emptyMediaSummaryResponse;

  /// No description provided for @summaryComplete.
  ///
  /// In en, this message translates to:
  /// **'Summary complete!'**
  String get summaryComplete;

  /// No description provided for @mediaSummarizationFailed.
  ///
  /// In en, this message translates to:
  /// **'Media summarization failed: {error}'**
  String mediaSummarizationFailed(String error);

  /// No description provided for @emptyYoutubeSummaryResponse.
  ///
  /// In en, this message translates to:
  /// **'The YouTube summary response was empty.'**
  String get emptyYoutubeSummaryResponse;

  /// No description provided for @youtubeSummarizationFailed.
  ///
  /// In en, this message translates to:
  /// **'YouTube summarization failed: {error}'**
  String youtubeSummarizationFailed(String error);

  /// No description provided for @selectOrRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Please select a video file or record a video first.'**
  String get selectOrRecordVideo;

  /// No description provided for @enterYoutubeUrlOrSelectVideo.
  ///
  /// In en, this message translates to:
  /// **'Please enter a YouTube URL or select a video first.'**
  String get enterYoutubeUrlOrSelectVideo;

  /// No description provided for @youtube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get youtube;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @youtubeUrl.
  ///
  /// In en, this message translates to:
  /// **'YouTube URL'**
  String get youtubeUrl;

  /// No description provided for @videoFile.
  ///
  /// In en, this message translates to:
  /// **'Video file'**
  String get videoFile;

  /// No description provided for @tapToSelectOrRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Tap to select a video file or record a video'**
  String get tapToSelectOrRecordVideo;

  /// No description provided for @sourceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Source language'**
  String get sourceLanguage;

  /// No description provided for @targetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get targetLanguage;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @summaryForLanguage.
  ///
  /// In en, this message translates to:
  /// **'Summary ({language}):'**
  String summaryForLanguage(String language);

  /// No description provided for @liveTranscript.
  ///
  /// In en, this message translates to:
  /// **'Live transcript:'**
  String get liveTranscript;

  /// No description provided for @targetLanguageOnly.
  ///
  /// In en, this message translates to:
  /// **'{language} only'**
  String targetLanguageOnly(String language);

  /// No description provided for @showBothLanguages.
  ///
  /// In en, this message translates to:
  /// **'Show both languages'**
  String get showBothLanguages;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @studyTools.
  ///
  /// In en, this message translates to:
  /// **'Study tools'**
  String get studyTools;

  /// No description provided for @summarize.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get summarize;

  /// No description provided for @studyNotes.
  ///
  /// In en, this message translates to:
  /// **'Study notes'**
  String get studyNotes;

  /// No description provided for @notesSaved.
  ///
  /// In en, this message translates to:
  /// **'Notes saved!'**
  String get notesSaved;

  /// No description provided for @translateFirst.
  ///
  /// In en, this message translates to:
  /// **'Translate first'**
  String get translateFirst;

  /// No description provided for @vocabulary.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary'**
  String get vocabulary;

  /// No description provided for @keyVocabularyExtracted.
  ///
  /// In en, this message translates to:
  /// **'Key vocabulary extracted!'**
  String get keyVocabularyExtracted;

  /// No description provided for @quiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get quiz;

  /// No description provided for @quizGenerationComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Quiz generation coming soon!'**
  String get quizGenerationComingSoon;

  /// No description provided for @textToSpeechError.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech error: {error}'**
  String textToSpeechError(String error);

  /// No description provided for @translatedSpokenPhrases.
  ///
  /// In en, this message translates to:
  /// **'Translated {count} spoken phrases...'**
  String translatedSpokenPhrases(int count);

  /// No description provided for @mediaContentContinues.
  ///
  /// In en, this message translates to:
  /// **'Media content continues...'**
  String get mediaContentContinues;

  /// No description provided for @nothingToPlay.
  ///
  /// In en, this message translates to:
  /// **'Nothing to play. Translate first.'**
  String get nothingToPlay;

  /// No description provided for @unableToPlayAudio.
  ///
  /// In en, this message translates to:
  /// **'Unable to play audio: {error}'**
  String unableToPlayAudio(String error);

  /// No description provided for @noCameraFound.
  ///
  /// In en, this message translates to:
  /// **'No camera was found on this device.'**
  String get noCameraFound;

  /// No description provided for @cameraOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open camera: {error}'**
  String cameraOpenFailed(String error);

  /// No description provided for @videoRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed: {error}'**
  String videoRecordingFailed(String error);

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stopRecording;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get startRecording;

  /// No description provided for @rwandaAfricaWorld.
  ///
  /// In en, this message translates to:
  /// **'Rwanda • Africa • World'**
  String get rwandaAfricaWorld;

  /// No description provided for @developedByCompany.
  ///
  /// In en, this message translates to:
  /// **'Developed by Prime Data Consulting Group LTD'**
  String get developedByCompany;

  /// No description provided for @connectingPeople.
  ///
  /// In en, this message translates to:
  /// **'Connecting People'**
  String get connectingPeople;

  /// No description provided for @subtitlesGenerated.
  ///
  /// In en, this message translates to:
  /// **'Subtitles generated!'**
  String get subtitlesGenerated;

  /// No description provided for @liveLocationActive.
  ///
  /// In en, this message translates to:
  /// **'Live location active!'**
  String get liveLocationActive;

  /// No description provided for @destinationSetTo.
  ///
  /// In en, this message translates to:
  /// **'Destination set to {location}'**
  String destinationSetTo(String location);

  /// No description provided for @destinationSet.
  ///
  /// In en, this message translates to:
  /// **'Destination set'**
  String get destinationSet;

  /// No description provided for @bestRouteSummary.
  ///
  /// In en, this message translates to:
  /// **'Best route: {distance} km, {duration} min'**
  String bestRouteSummary(String distance, String duration);

  /// No description provided for @offlineDirectLine.
  ///
  /// In en, this message translates to:
  /// **'Offline mode - direct line'**
  String get offlineDirectLine;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'rw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'rw':
      return AppLocalizationsRw();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
