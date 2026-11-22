// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mpuza - Rwanda';

  @override
  String get retry => 'Retry';

  @override
  String get continueToLogin => 'Continue to Login';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKinyarwanda => 'Kinyarwanda';

  @override
  String get languageFrench => 'French';

  @override
  String languageUpdateFailed(String error) {
    return 'Could not change language: $error';
  }

  @override
  String get openNavigationMenu => 'Open navigation menu';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get home => 'Home';

  @override
  String get textTranslation => 'Text Translation';

  @override
  String get speechTranslation => 'Speech Translation';

  @override
  String get videoTranslation => 'Video Translation';

  @override
  String get cameraTranslation => 'Camera Translation';

  @override
  String get startTranslating => 'Start Translating';

  @override
  String get educationTools => 'Education Tools';

  @override
  String get underDevelopment => 'Under Development';

  @override
  String get offlinePacks => 'Offline Packs';

  @override
  String get driverMode => 'Driver Mode';

  @override
  String get googleMaps => 'Google Maps';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get aboutBlurb =>
      'Breaking language barriers in Rwanda, Africa & World.';

  @override
  String get supportedLanguages =>
      'Supporting Kinyarwanda, English, and French.';

  @override
  String get madeWithPride => '🇷🇼 Made with pride in Rwanda 🇷🇼';

  @override
  String get logOut => 'Log out';

  @override
  String get ok => 'OK';

  @override
  String get version => 'Version 1.0.0';

  @override
  String get settingsTitle => 'App Settings';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get enableDarkTheme => 'Enable dark theme';

  @override
  String get defaultLanguage => 'Default Language';

  @override
  String get speechRate => 'Speech Rate';

  @override
  String get normal => 'Normal';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String cacheUsage(String size) {
    return '$size used';
  }

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get loginToContinue => 'Log in to continue translating.';

  @override
  String get emailOrUsername => 'Email or username';

  @override
  String get password => 'Password';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get showPassword => 'Show password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get login => 'Log in';

  @override
  String get newToMpuza => 'New to MPUZA? ';

  @override
  String get createAccount => 'Create account';

  @override
  String get signupStepOne => 'STEP 1 OF 2';

  @override
  String get joinMpuza => 'Join MPUZA and start translating across languages.';

  @override
  String get username => 'Username';

  @override
  String get emailAddress => 'Email address';

  @override
  String get invalidEmailAddress => 'Enter a valid email address';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get continueLabel => 'Continue';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get signupStepTwo => 'STEP 2 OF 2';

  @override
  String get aboutYouAndSecurity => 'About you & security';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get preferNotToSay => 'Prefer not to say';

  @override
  String get country => 'Country';

  @override
  String get countryRwanda => 'Rwanda';

  @override
  String get countryBurundi => 'Burundi';

  @override
  String get countryDrCongo => 'Democratic Republic of the Congo';

  @override
  String get countryKenya => 'Kenya';

  @override
  String get countryTanzania => 'Tanzania';

  @override
  String get countryUganda => 'Uganda';

  @override
  String get createStrongPassword => 'Create a strong password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get reenterPassword => 'Re-enter your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordsMatch => 'Passwords match';

  @override
  String get verifyYourEmail => 'Verify your email';

  @override
  String verificationCodeSentTo(String email) {
    return 'We sent a 6-digit code to\n$email';
  }

  @override
  String get codeExpiresInPrefix => 'Code expires in ';

  @override
  String get didntGetIt => 'Didn\'t get it? ';

  @override
  String resendIn(String duration) {
    return 'Resend in $duration';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String get verify => 'Verify';

  @override
  String get wrongEmail => 'Wrong email? ';

  @override
  String get changeIt => 'Change it';

  @override
  String get emailVerified => 'Email verified!';

  @override
  String get accountReadyMessage =>
      'Your MPUZA account is ready. Log in with your email or username to start translating.';

  @override
  String get goToLogin => 'Go to Login';

  @override
  String get forgotPasswordInstructions =>
      'Enter the email address linked to your MPUZA account. We will send you a reset code.';

  @override
  String get sendResetCode => 'Send reset code';

  @override
  String get rememberPassword => 'Remember your password? ';

  @override
  String get resetYourPassword => 'Reset your password';

  @override
  String resetCodeSentTo(String email) {
    return 'Enter the code sent to\n$email';
  }

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get back => 'Back';

  @override
  String get weak => 'Weak';

  @override
  String get fair => 'Fair';

  @override
  String get strong => 'Strong';

  @override
  String get passwordStrength => 'Password strength';

  @override
  String get eightPlusCharacters => '8+ characters';

  @override
  String get uppercase => 'Uppercase';

  @override
  String get lowercase => 'Lowercase';

  @override
  String get numberAndSymbol => 'Number & symbol';

  @override
  String get requiredField => 'This field is required';

  @override
  String get passwordStrengthRequirement =>
      'Use 8+ characters with uppercase, lowercase, a number and a symbol';

  @override
  String get selectGender => 'Select a gender option to continue.';

  @override
  String get enterSixDigitCode => 'Enter the 6-digit code to continue.';

  @override
  String get passwordResetComplete => 'Password reset. You can now log in.';

  @override
  String get translationSuccessful => 'Translation successful';

  @override
  String get translationTimedOut =>
      'Translation is taking longer than expected. Please try again.';

  @override
  String translationFailed(String error) {
    return 'Translation failed: $error';
  }

  @override
  String get copiedToClipboard => 'Copied to clipboard!';

  @override
  String get removedFromFavorites => 'Removed from favorites!';

  @override
  String get savedToFavorites => 'Saved to favorites!';

  @override
  String get sourceText => 'Source Text';

  @override
  String get sourceTextHint => 'Enter text to translate...';

  @override
  String characterCount(int count) {
    return '$count characters';
  }

  @override
  String get translating => 'Translating...';

  @override
  String get translate => 'Translate';

  @override
  String get translation => 'Translation';

  @override
  String get translationPlaceholder => 'Translation will appear here';

  @override
  String get cameraPermissionRequired => 'Camera permission required';

  @override
  String get noTextFoundInImage => 'No text found in image';

  @override
  String imageProcessingFailed(String error) {
    return 'Error processing image: $error';
  }

  @override
  String imageTranslationFailed(String error) {
    return 'Error translating text: $error';
  }

  @override
  String get takeOrUploadImage => 'Take or Upload Image';

  @override
  String get takeRearPhoto => 'Take Photo (Rear)';

  @override
  String get takeFrontPhoto => 'Take Photo (Front)';

  @override
  String get uploadPhoto => 'Upload Photo';

  @override
  String get offlineTranslationPacks => 'Offline Translation Packs';

  @override
  String get deviceStorage => 'Device Storage';

  @override
  String storageUsage(String used, String free) {
    return '$used used • $free free';
  }

  @override
  String get myPacks => 'My Packs';

  @override
  String get viewAll => 'View All';

  @override
  String get free => 'Free';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get download => 'Download';

  @override
  String downloadingPack(String pack) {
    return 'Downloading $pack...';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get basicKinyarwandaPack => 'Basic Kinyarwanda Pack';

  @override
  String get essentialPhrasesDescription =>
      'Essential phrases and common vocabulary';

  @override
  String get completeKinyarwandaPack => 'Complete Kinyarwanda Pack';

  @override
  String get completeDictionaryDescription =>
      'Full Kinyarwanda-English-French dictionary';

  @override
  String get motoristCommunicationPack => 'Motorist Communication Pack';

  @override
  String get transportationPhrasesDescription =>
      'Transportation and navigation phrases';

  @override
  String get medicalEmergencyPack => 'Medical & Emergency Pack';

  @override
  String get healthcareVocabularyDescription =>
      'Healthcare and emergency vocabulary';

  @override
  String get educationPack => 'Education Pack';

  @override
  String get academicVocabularyDescription =>
      'Academic vocabulary and terminology';

  @override
  String get tourismHospitalityPack => 'Tourism & Hospitality Pack';

  @override
  String get tourismPhrasesDescription =>
      'Tourist phrases and service vocabulary';

  @override
  String get lectureSummarizer => 'Lecture Summarizer';

  @override
  String get comingSoon => 'Coming Soon!';

  @override
  String get autoSummarizeLectures => 'Auto-summarization of lectures';

  @override
  String get studyNotesGeneration => 'Study notes generation';

  @override
  String get vocabularyExtraction => 'Vocabulary extraction';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get motoristModeActive => 'Motorist Mode Active';

  @override
  String get listeningForCommands => 'Listening for commands...';

  @override
  String get tapToActivate => 'Tap to activate';

  @override
  String get navigate => 'Navigate';

  @override
  String get fare => 'Fare';

  @override
  String get call => 'Call';

  @override
  String get currentlyNavigating => 'Currently navigating';

  @override
  String get readyForPassengers => 'Ready for passengers';

  @override
  String get followTheRoute => 'Follow the route';

  @override
  String get tapToStartNavigation => 'Tap to start navigation';

  @override
  String get voiceCommands => 'Voice Commands';

  @override
  String get listening => 'Listening...';

  @override
  String get tapToSpeak => 'Tap to speak';

  @override
  String get enableLocationServices => 'Please enable location services';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Location permissions permanently denied';

  @override
  String get showingKigaliCenter => 'Showing Kigali Center';

  @override
  String get placeSearchFailed => 'Search failed. Please try again.';

  @override
  String get noPhoneAvailable => 'No phone available';

  @override
  String placeCategory(String category) {
    return '$category';
  }

  @override
  String get freeGeocodingNoApiKey => 'Free geocoding - no API key';

  @override
  String get close => 'Close';

  @override
  String get navigateHere => 'Navigate Here';

  @override
  String get selectedLocation => 'Selected Location';

  @override
  String get setDestinationFirst => 'Please set a destination first';

  @override
  String headDirection(String direction) {
    return 'Head $direction';
  }

  @override
  String get north => 'North';

  @override
  String get south => 'South';

  @override
  String get east => 'East';

  @override
  String get west => 'West';

  @override
  String get northeast => 'Northeast';

  @override
  String get northwest => 'Northwest';

  @override
  String get southeast => 'Southeast';

  @override
  String get southwest => 'Southwest';

  @override
  String get offlineDirectRoute => 'Offline route (direct line)';

  @override
  String get freeMapsRwanda => '🗺️ Free Maps - Rwanda';

  @override
  String get liveLocationFreeGeocoding => 'Live location • free geocoding';

  @override
  String get hideNearbyPlaces => 'Hide Nearby Places';

  @override
  String get myLocation => 'My Location';

  @override
  String get gettingLiveLocation => 'Getting your live location...';

  @override
  String get zoomIn => 'Zoom In';

  @override
  String get zoomOut => 'Zoom Out';

  @override
  String get searchPlaceHint => 'Search any place in Rwanda...';

  @override
  String get nearbyPlaces => 'Nearby Places';

  @override
  String get bestRoute => 'Best Route';

  @override
  String get destination => 'Destination';

  @override
  String minutesAbbreviation(String minutes) {
    return '$minutes min';
  }

  @override
  String get distance => 'Distance';

  @override
  String get travelMode => 'Travel Mode';

  @override
  String get summary => 'Summary';

  @override
  String get routeReady => 'Route ready';

  @override
  String get setDestination => 'Set Destination';

  @override
  String get getDirections => 'Get Directions';

  @override
  String get clearRoute => 'Clear Route';

  @override
  String get hospitals => 'Hospitals';

  @override
  String get hotels => 'Hotels';

  @override
  String get restaurants => 'Restaurants';

  @override
  String get coffeeShops => 'Coffee Shops';

  @override
  String get bars => 'Bars';

  @override
  String get car => 'Car';

  @override
  String get walk => 'Walk';

  @override
  String get bicycle => 'Bicycle';

  @override
  String get microphonePermissionRequired =>
      'Microphone permission is required to use speech recognition';

  @override
  String get noSpeechDetected =>
      'No speech detected. Speak clearly and try again.';

  @override
  String get microphonePermissionDenied => 'Microphone permission denied';

  @override
  String get speechRecognitionError => 'Speech recognition error';

  @override
  String get speechRecognitionUnavailable =>
      'Speech recognition is not available. Please allow microphone access and try again.';

  @override
  String get couldNotStartListening =>
      'Could not start listening. Please allow microphone access and try again.';

  @override
  String get browserMicrophonePermissionRequired =>
      'Microphone permission required: use the lock icon in your browser address bar to allow microphone access.';

  @override
  String get noMicrophoneDetected =>
      'No microphone detected. Please connect a microphone.';

  @override
  String get microphoneReady => 'Microphone ready. Speak clearly now.';

  @override
  String couldNotStartListeningWithError(String error) {
    return 'Could not start listening. Error: $error';
  }

  @override
  String audioSelected(String fileName) {
    return 'Audio selected: $fileName';
  }

  @override
  String get audioTranscribed => 'Audio transcribed successfully!';

  @override
  String audioSelectionFailed(String error) {
    return 'Error picking audio: $error';
  }

  @override
  String get selectedAudioCouldNotBeRead =>
      'The selected audio file could not be read.';

  @override
  String get emptySpeechTranslationResponse =>
      'The speech translation response was empty.';

  @override
  String get translationCompleted => 'Translation completed';

  @override
  String get recordVoice => 'Record Voice';

  @override
  String get uploadAudio => 'Upload Audio';

  @override
  String get fromLanguage => 'From';

  @override
  String get toLanguage => 'To';

  @override
  String get outputOptions => 'Output Options:';

  @override
  String get textOutput => '📝 Text';

  @override
  String get audioOutput => '🔊 Audio';

  @override
  String get bothOutputs => '📝🔊 Both';

  @override
  String get processingAudio => 'Processing Audio...';

  @override
  String get convertingSpeechToText => 'Converting speech to text';

  @override
  String get tapToStartRecording => 'Tap to start recording';

  @override
  String confidence(String percentage) {
    return 'Confidence: $percentage%';
  }

  @override
  String get recognizedSpeech => 'Recognized Speech';

  @override
  String get shareComingSoon => 'Share feature coming soon!';

  @override
  String get recentTranslations => 'Recent Translations';

  @override
  String get liveTranslationTimedOut =>
      'Live translation timed out. Please try again with a shorter video.';

  @override
  String get mediaPermissionPermanentlyDenied =>
      'Camera or microphone access is permanently denied. Please enable it in app settings.';

  @override
  String get cameraMicrophonePermissionsRequired =>
      'Camera and microphone permissions are required to record video.';

  @override
  String get chooseVideoSource => 'Choose how to provide your video';

  @override
  String get recordVideo => 'Record video';

  @override
  String get recordVideoDescription => 'Use your camera to capture a new video';

  @override
  String get uploadVideoFromStorage => 'Upload video from local storage';

  @override
  String get pickVideoDescription => 'Pick a video file from your device';

  @override
  String get noVideoSelected => 'No video file was selected.';

  @override
  String videoSelected(String filename) {
    return 'Video selected: $filename';
  }

  @override
  String videoPickFailed(String error) {
    return 'Unable to pick the video file: $error';
  }

  @override
  String get noVideoRecorded => 'No video was recorded.';

  @override
  String videoRecorded(String filename) {
    return 'Video recorded: $filename';
  }

  @override
  String videoRecordFailed(String error) {
    return 'Unable to record the video: $error';
  }

  @override
  String get noMediaSelected => 'No media selected';

  @override
  String get preparingLiveSubtitles => 'Preparing live translated subtitles...';

  @override
  String get invalidTranslationResponse =>
      'Unexpected response format from translation service.';

  @override
  String get translationComplete => 'Translation complete!';

  @override
  String mediaUploadFailed(String error) {
    return 'Media upload failed: $error';
  }

  @override
  String get enterYoutubeUrl => 'Please enter a YouTube URL';

  @override
  String get youtubeLiveTranslationFailed => 'YouTube live translation failed';

  @override
  String youtubeLiveTranslationFailedWithError(String error) {
    return 'YouTube live translation failed: $error';
  }

  @override
  String get noSpokenPhrasesDetected => 'No spoken phrases were detected.';

  @override
  String get liveSubtitlesReady => 'Live subtitles ready.';

  @override
  String get liveTranslationFailed => 'Live translation failed';

  @override
  String get emptyMediaSummaryResponse =>
      'The media summary response was empty.';

  @override
  String get summaryComplete => 'Summary complete!';

  @override
  String mediaSummarizationFailed(String error) {
    return 'Media summarization failed: $error';
  }

  @override
  String get emptyYoutubeSummaryResponse =>
      'The YouTube summary response was empty.';

  @override
  String youtubeSummarizationFailed(String error) {
    return 'YouTube summarization failed: $error';
  }

  @override
  String get selectOrRecordVideo =>
      'Please select a video file or record a video first.';

  @override
  String get enterYoutubeUrlOrSelectVideo =>
      'Please enter a YouTube URL or select a video first.';

  @override
  String get youtube => 'YouTube';

  @override
  String get video => 'Video';

  @override
  String get youtubeUrl => 'YouTube URL';

  @override
  String get videoFile => 'Video file';

  @override
  String get tapToSelectOrRecordVideo =>
      'Tap to select a video file or record a video';

  @override
  String get sourceLanguage => 'Source language';

  @override
  String get targetLanguage => 'Target language';

  @override
  String get auto => 'Auto';

  @override
  String summaryForLanguage(String language) {
    return 'Summary ($language):';
  }

  @override
  String get liveTranscript => 'Live transcript:';

  @override
  String targetLanguageOnly(String language) {
    return '$language only';
  }

  @override
  String get showBothLanguages => 'Show both languages';

  @override
  String get stop => 'Stop';

  @override
  String get listen => 'Listen';

  @override
  String get studyTools => 'Study tools';

  @override
  String get summarize => 'Summarize';

  @override
  String get studyNotes => 'Study notes';

  @override
  String get notesSaved => 'Notes saved!';

  @override
  String get translateFirst => 'Translate first';

  @override
  String get vocabulary => 'Vocabulary';

  @override
  String get keyVocabularyExtracted => 'Key vocabulary extracted!';

  @override
  String get quiz => 'Quiz';

  @override
  String get quizGenerationComingSoon => 'Quiz generation coming soon!';

  @override
  String textToSpeechError(String error) {
    return 'Text-to-speech error: $error';
  }

  @override
  String translatedSpokenPhrases(int count) {
    return 'Translated $count spoken phrases...';
  }

  @override
  String get mediaContentContinues => 'Media content continues...';

  @override
  String get nothingToPlay => 'Nothing to play. Translate first.';

  @override
  String unableToPlayAudio(String error) {
    return 'Unable to play audio: $error';
  }

  @override
  String get noCameraFound => 'No camera was found on this device.';

  @override
  String cameraOpenFailed(String error) {
    return 'Unable to open camera: $error';
  }

  @override
  String videoRecordingFailed(String error) {
    return 'Recording failed: $error';
  }

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get startRecording => 'Start recording';

  @override
  String get rwandaAfricaWorld => 'Rwanda • Africa • World';

  @override
  String get developedByCompany =>
      'Developed by Prime Data Consulting Group LTD';

  @override
  String get connectingPeople => 'Connecting People';

  @override
  String get subtitlesGenerated => 'Subtitles generated!';

  @override
  String get liveLocationActive => 'Live location active!';

  @override
  String destinationSetTo(String location) {
    return 'Destination set to $location';
  }

  @override
  String get destinationSet => 'Destination set';

  @override
  String bestRouteSummary(String distance, String duration) {
    return 'Best route: $distance km, $duration min';
  }

  @override
  String get offlineDirectLine => 'Offline mode - direct line';
}
