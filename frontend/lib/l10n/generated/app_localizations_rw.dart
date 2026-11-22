// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kinyarwanda (`rw`).
class AppLocalizationsRw extends AppLocalizations {
  AppLocalizationsRw([String locale = 'rw']) : super(locale);

  @override
  String get appTitle => 'Mpuza - Rwanda';

  @override
  String get retry => 'Ongera ugerageze';

  @override
  String get continueToLogin => 'Komeza winjire';

  @override
  String get selectLanguage => 'Hitamo ururimi';

  @override
  String get languageEnglish => 'Icyongereza';

  @override
  String get languageKinyarwanda => 'Ikinyarwanda';

  @override
  String get languageFrench => 'Igifaransa';

  @override
  String languageUpdateFailed(String error) {
    return 'Ntibyashobotse guhindura ururimi: $error';
  }

  @override
  String get openNavigationMenu => 'Fungura menu y\'urujyendo';

  @override
  String get collapseSidebar => 'Gufunga akabari ko ku ruhande';

  @override
  String get home => 'Ahabanza';

  @override
  String get textTranslation => 'Ubusemuzi bw\'inyandiko';

  @override
  String get speechTranslation => 'Ubusemuzi bw\'ijwi';

  @override
  String get videoTranslation => 'Ubusemuzi bwa videwo';

  @override
  String get cameraTranslation => 'Ubusemuzi ukoresheje kamera';

  @override
  String get startTranslating => 'Tangira gusemura';

  @override
  String get educationTools => 'Ibikoresho by\'uburezi';

  @override
  String get underDevelopment => 'Biracyategurwa';

  @override
  String get offlinePacks => 'Ubusemuzi butari kuri interineti';

  @override
  String get driverMode => 'Uburyo bw\'abatwara ibinyabiziga';

  @override
  String get googleMaps => 'Google Maps';

  @override
  String get settings => 'Igenamiterere';

  @override
  String get about => 'Ibyerekeye';

  @override
  String get aboutBlurb =>
      'Dukuraho inzitizi z\'ururimi mu Rwanda, muri Afurika no ku isi.';

  @override
  String get supportedLanguages =>
      'Dushyigikira Ikinyarwanda, Icyongereza n\'Igifaransa.';

  @override
  String get madeWithPride => '🇷🇼 Byakozwe mu ishema mu Rwanda 🇷🇼';

  @override
  String get logOut => 'Gusohoka';

  @override
  String get ok => 'Yego';

  @override
  String get version => 'Verisiyo 1.0.0';

  @override
  String get settingsTitle => 'Igenamiterere rya porogaramu';

  @override
  String get darkMode => 'Uburyo bwijimye';

  @override
  String get enableDarkTheme => 'Koresha isura yijimye';

  @override
  String get defaultLanguage => 'Ururimi mburabuzi';

  @override
  String get speechRate => 'Umuvuduko w\'ijwi';

  @override
  String get normal => 'Bisanzwe';

  @override
  String get clearCache => 'Siba amakuru y\'agateganyo';

  @override
  String cacheUsage(String size) {
    return 'Hakozwe $size';
  }

  @override
  String get welcomeBack => 'Murakaza neza nanone';

  @override
  String get loginToContinue => 'Injira kugira ukomeze gusemura.';

  @override
  String get emailOrUsername => 'Imeyili cyangwa izina ukoresha';

  @override
  String get password => 'Ijambo ry\'ibanga';

  @override
  String get enterPassword => 'Andika ijambo ry\'ibanga';

  @override
  String get hidePassword => 'Hisha ijambo ry\'ibanga';

  @override
  String get showPassword => 'Erekana ijambo ry\'ibanga';

  @override
  String get forgotPassword => 'Wibagiwe ijambo ry\'ibanga?';

  @override
  String get login => 'Injira';

  @override
  String get newToMpuza => 'Ntabwo urakoresha MPUZA? ';

  @override
  String get createAccount => 'Fungura konti';

  @override
  String get signupStepOne => 'INTAMBWE YA 1 KURI 2';

  @override
  String get joinMpuza =>
      'Iyunge na MPUZA utangire gusemura mu ndimi zitandukanye.';

  @override
  String get username => 'Izina ukoresha';

  @override
  String get emailAddress => 'Aderesi ya imeyili';

  @override
  String get invalidEmailAddress => 'Andika aderesi ya imeyili yemewe';

  @override
  String get phoneNumber => 'Nimero ya telefoni';

  @override
  String get continueLabel => 'Komeza';

  @override
  String get alreadyHaveAccount => 'Usanzwe ufite konti? ';

  @override
  String get signupStepTwo => 'INTAMBWE YA 2 KURI 2';

  @override
  String get aboutYouAndSecurity => 'Ibyerekeye nawe n\'umutekano';

  @override
  String get gender => 'Igitsina';

  @override
  String get male => 'Gabo';

  @override
  String get female => 'Gore';

  @override
  String get preferNotToSay => 'Simbyifuza kuvuga';

  @override
  String get country => 'Igihugu';

  @override
  String get countryRwanda => 'Rwanda';

  @override
  String get countryBurundi => 'Uburundi';

  @override
  String get countryDrCongo => 'Repubulika Iharanira Demokarasi ya Kongo';

  @override
  String get countryKenya => 'Kenya';

  @override
  String get countryTanzania => 'Tanzaniya';

  @override
  String get countryUganda => 'Uganda';

  @override
  String get createStrongPassword => 'Kora ijambo ry\'ibanga rikomeye';

  @override
  String get confirmPassword => 'Emeza ijambo ry\'ibanga';

  @override
  String get reenterPassword => 'Ongera wandike ijambo ry\'ibanga';

  @override
  String get passwordsDoNotMatch => 'Amagambo y\'ibanga ntahuye';

  @override
  String get passwordsMatch => 'Amagambo y\'ibanga arahuye';

  @override
  String get verifyYourEmail => 'Emeza imeyili yawe';

  @override
  String verificationCodeSentTo(String email) {
    return 'Twohereje kode y\'imibare 6 kuri\n$email';
  }

  @override
  String get codeExpiresInPrefix => 'Kode irarangira mu ';

  @override
  String get didntGetIt => 'Ntabwo wayibonye? ';

  @override
  String resendIn(String duration) {
    return 'Ongera wohereze mu $duration';
  }

  @override
  String get resendCode => 'Ongera wohereze kode';

  @override
  String get verify => 'Emeza';

  @override
  String get wrongEmail => 'Imeyili si yo? ';

  @override
  String get changeIt => 'Yihindure';

  @override
  String get emailVerified => 'Imeyili yemejwe!';

  @override
  String get accountReadyMessage =>
      'Konti yawe ya MPUZA yiteguye. Injira ukoresheje imeyili cyangwa izina ukoresha utangire gusemura.';

  @override
  String get goToLogin => 'Jya ku kwinjira';

  @override
  String get forgotPasswordInstructions =>
      'Andika aderesi ya imeyili ijyanye na konti yawe ya MPUZA. Tuzohereza kode yo gusubiramo ijambo ry\'ibanga.';

  @override
  String get sendResetCode => 'Ohereza kode yo gusubiramo';

  @override
  String get rememberPassword => 'Wibutse ijambo ry\'ibanga? ';

  @override
  String get resetYourPassword => 'Subiramo ijambo ry\'ibanga';

  @override
  String resetCodeSentTo(String email) {
    return 'Andika kode yohererejwe kuri\n$email';
  }

  @override
  String get newPassword => 'Ijambo ry\'ibanga rishya';

  @override
  String get confirmNewPassword => 'Emeza ijambo ry\'ibanga rishya';

  @override
  String get resetPassword => 'Subiramo ijambo ry\'ibanga';

  @override
  String get back => 'Subira inyuma';

  @override
  String get weak => 'Ryoroshye';

  @override
  String get fair => 'Riringaniye';

  @override
  String get strong => 'Rikomeye';

  @override
  String get passwordStrength => 'Imbaraga z\'ijambo ry\'ibanga';

  @override
  String get eightPlusCharacters => 'Inyuguti 8 cyangwa zirenga';

  @override
  String get uppercase => 'Inyuguti nkuru';

  @override
  String get lowercase => 'Inyuguti nto';

  @override
  String get numberAndSymbol => 'Umubare n\'ikimenyetso';

  @override
  String get requiredField => 'Iki gice kirakenewe';

  @override
  String get passwordStrengthRequirement =>
      'Koresha inyuguti 8 cyangwa zirenga, harimo inyuguti nkuru, nto, umubare n\'ikimenyetso';

  @override
  String get selectGender => 'Hitamo igitsina kugira ukomeze.';

  @override
  String get enterSixDigitCode => 'Andika kode y\'imibare 6 kugira ukomeze.';

  @override
  String get passwordResetComplete =>
      'Ijambo ry\'ibanga ryasubiwemo. Ushobora kwinjira ubu.';

  @override
  String get translationSuccessful => 'Ubusemuzi bwagenze neza';

  @override
  String get translationTimedOut =>
      'Ubusemuzi butinze kurenza uko byari byitezwe. Ongera ugerageze.';

  @override
  String translationFailed(String error) {
    return 'Ubusemuzi bwanze: $error';
  }

  @override
  String get copiedToClipboard => 'Byakoporowe!';

  @override
  String get removedFromFavorites => 'Byakuwe mu byo ukunda!';

  @override
  String get savedToFavorites => 'Byabitswe mu byo ukunda!';

  @override
  String get sourceText => 'Inyandiko y\'umwimerere';

  @override
  String get sourceTextHint => 'Andika inyandiko ushaka gusemura...';

  @override
  String characterCount(int count) {
    return 'Inyuguti: $count';
  }

  @override
  String get translating => 'Birimo gusemurwa...';

  @override
  String get translate => 'Semuza';

  @override
  String get translation => 'Ubusemuzi';

  @override
  String get translationPlaceholder => 'Ubusemuzi buzagaragara hano';

  @override
  String get cameraPermissionRequired => 'Uruhushya rwa kamera rurakenewe';

  @override
  String get noTextFoundInImage => 'Nta nyandiko yabonetse ku ifoto';

  @override
  String imageProcessingFailed(String error) {
    return 'Ikosa mu gutunganya ifoto: $error';
  }

  @override
  String imageTranslationFailed(String error) {
    return 'Ikosa mu gusemura inyandiko: $error';
  }

  @override
  String get takeOrUploadImage => 'Fata cyangwa wohereze ifoto';

  @override
  String get takeRearPhoto => 'Fata ifoto ukoresheje kamera y\'inyuma';

  @override
  String get takeFrontPhoto => 'Fata ifoto ukoresheje kamera y\'imbere';

  @override
  String get uploadPhoto => 'Ohereza ifoto';

  @override
  String get offlineTranslationPacks =>
      'Amapaki yo gusemura udafite interineti';

  @override
  String get deviceStorage => 'Ububiko bw\'igikoresho';

  @override
  String storageUsage(String used, String free) {
    return 'Hakozwe $used • hasigaye $free';
  }

  @override
  String get myPacks => 'Amapaki yanjye';

  @override
  String get viewAll => 'Reba byose';

  @override
  String get free => 'Ubuntu';

  @override
  String get downloaded => 'Yamanuwe';

  @override
  String get download => 'Manura';

  @override
  String downloadingPack(String pack) {
    return 'Birimo kumanura $pack...';
  }

  @override
  String get cancel => 'Hagarika';

  @override
  String get basicKinyarwandaPack => 'Ipaki y\'ibanze y\'Ikinyarwanda';

  @override
  String get essentialPhrasesDescription =>
      'Amagambo y\'ingenzi n\'ay\'ikoreshwa rya buri munsi';

  @override
  String get completeKinyarwandaPack => 'Ipaki yuzuye y\'Ikinyarwanda';

  @override
  String get completeDictionaryDescription =>
      'Inkoranyamagambo yuzuye y\'Ikinyarwanda-Icyongereza- Igifaransa';

  @override
  String get motoristCommunicationPack =>
      'Ipaki y\'itumanaho ry\'abatwara ibinyabiziga';

  @override
  String get transportationPhrasesDescription =>
      'Amagambo ajyanye n\'ingendo n\'icyerekezo';

  @override
  String get medicalEmergencyPack => 'Ipaki y\'ubuvuzi n\'ubutabazi bwihuse';

  @override
  String get healthcareVocabularyDescription =>
      'Amagambo y\'ubuvuzi n\'ubutabazi';

  @override
  String get educationPack => 'Ipaki y\'uburezi';

  @override
  String get academicVocabularyDescription =>
      'Amagambo n\'ibisobanuro by\'amasomo';

  @override
  String get tourismHospitalityPack => 'Ipaki y\'ubukerarugendo n\'amahoteli';

  @override
  String get tourismPhrasesDescription =>
      'Amagambo akoreshwa n\'abakerarugendo mu mirimo';

  @override
  String get lectureSummarizer => 'Incamake y\'amasomo';

  @override
  String get comingSoon => 'Biraza vuba!';

  @override
  String get autoSummarizeLectures => 'Gukora incamake y\'amasomo byikora';

  @override
  String get studyNotesGeneration => 'Gukora inyandiko z\'isomo';

  @override
  String get vocabularyExtraction => 'Gutoranya amagambo y\'ingenzi';

  @override
  String get backToHome => 'Subira ahabanza';

  @override
  String get motoristModeActive => 'Uburyo bw\'abatwara burakora';

  @override
  String get listeningForCommands => 'Birimo gutegereza amabwiriza...';

  @override
  String get tapToActivate => 'Kanda kugira utangize';

  @override
  String get navigate => 'Kuyobora';

  @override
  String get fare => 'Igiciro';

  @override
  String get call => 'Hamagara';

  @override
  String get currentlyNavigating => 'Urimo kuyoborwa';

  @override
  String get readyForPassengers => 'Witeguye kwakira abagenzi';

  @override
  String get followTheRoute => 'Kurikira inzira';

  @override
  String get tapToStartNavigation => 'Kanda utangire kuyoborwa';

  @override
  String get voiceCommands => 'Amabwiriza y\'ijwi';

  @override
  String get listening => 'Birimo kumva...';

  @override
  String get tapToSpeak => 'Kanda uvuge';

  @override
  String get enableLocationServices => 'Fungura serivisi zo kumenya aho uri';

  @override
  String get locationPermissionDenied => 'Uruhushya rwo kumenya aho uri rwanze';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Uruhushya rwo kumenya aho uri rwaranzwe burundu';

  @override
  String get showingKigaliCenter => 'Hagaragazwa hagati mu Mujyi wa Kigali';

  @override
  String get placeSearchFailed => 'Gushakisha byanze. Ongera ugerageze.';

  @override
  String get noPhoneAvailable => 'Nta nimero ya telefoni ihari';

  @override
  String placeCategory(String category) {
    return '$category';
  }

  @override
  String get freeGeocodingNoApiKey =>
      'Kumenya aho hantu ni ubuntu, nta rufunguzo rwa API';

  @override
  String get close => 'Funga';

  @override
  String get navigateHere => 'Nyobora hano';

  @override
  String get selectedLocation => 'Ahantu wahisemo';

  @override
  String get setDestinationFirst => 'Banza ushyireho aho ujya';

  @override
  String headDirection(String direction) {
    return 'Komeza werekeza $direction';
  }

  @override
  String get north => 'mu majyaruguru';

  @override
  String get south => 'mu majyepfo';

  @override
  String get east => 'iburasirazuba';

  @override
  String get west => 'iburengerazuba';

  @override
  String get northeast => 'mu majyaruguru y\'uburasirazuba';

  @override
  String get northwest => 'mu majyaruguru y\'iburengerazuba';

  @override
  String get southeast => 'mu majyepfo y\'uburasirazuba';

  @override
  String get southwest => 'mu majyepfo y\'iburengerazuba';

  @override
  String get offlineDirectRoute =>
      'Inzira itari kuri interineti (umurongo ugororotse)';

  @override
  String get freeMapsRwanda => '🗺️ Amakarita y\'ubuntu - Rwanda';

  @override
  String get liveLocationFreeGeocoding =>
      'Ahantu uri ako kanya • kumenya ahantu ku buntu';

  @override
  String get hideNearbyPlaces => 'Hisha ahantu hafi';

  @override
  String get myLocation => 'Aho ndi';

  @override
  String get gettingLiveLocation => 'Birimo gushaka aho uri...';

  @override
  String get zoomIn => 'Kwegereza';

  @override
  String get zoomOut => 'Kurekura';

  @override
  String get searchPlaceHint => 'Shaka ahantu hose mu Rwanda...';

  @override
  String get nearbyPlaces => 'Ahantu hafi';

  @override
  String get bestRoute => 'Inzira nziza';

  @override
  String get destination => 'Aho ujya';

  @override
  String minutesAbbreviation(String minutes) {
    return 'Iminota $minutes';
  }

  @override
  String get distance => 'Intera';

  @override
  String get travelMode => 'Uburyo bw\'urugendo';

  @override
  String get summary => 'Incamake';

  @override
  String get routeReady => 'Inzira yiteguye';

  @override
  String get setDestination => 'Shyiraho aho ujya';

  @override
  String get getDirections => 'Shaka icyerekezo';

  @override
  String get clearRoute => 'Siba inzira';

  @override
  String get hospitals => 'Ibitaro';

  @override
  String get hotels => 'Amahoteri';

  @override
  String get restaurants => 'Restaurants';

  @override
  String get coffeeShops => 'Aho banywera ikawa';

  @override
  String get bars => 'Utubari';

  @override
  String get car => 'Imodoka';

  @override
  String get walk => 'Kugenda n\'amaguru';

  @override
  String get bicycle => 'Igare';

  @override
  String get microphonePermissionRequired =>
      'Uruhushya rwa mikoro rurakenewe kugira ngo umenye ijwi';

  @override
  String get noSpeechDetected =>
      'Nta jambo ryumvikanye. Vuga neza wongere ugerageze.';

  @override
  String get microphonePermissionDenied => 'Uruhushya rwa mikoro rwanze';

  @override
  String get speechRecognitionError => 'Ikosa mu kumenya ijwi';

  @override
  String get speechRecognitionUnavailable =>
      'Kumenya ijwi ntibishoboka. Emera gukoresha mikoro wongere ugerageze.';

  @override
  String get couldNotStartListening =>
      'Ntibyashobotse gutangira kumva. Emera gukoresha mikoro wongere ugerageze.';

  @override
  String get browserMicrophonePermissionRequired =>
      'Uruhushya rwa mikoro rurakenewe: koresha ikimenyetso cy\'urufunguzo muri aderesi ya mushakisha wemere mikoro.';

  @override
  String get noMicrophoneDetected =>
      'Nta mikoro yabonetse. Yomeke ku gikoresho.';

  @override
  String get microphoneReady => 'Mikoro iriteguye. Vuga neza.';

  @override
  String couldNotStartListeningWithError(String error) {
    return 'Ntibyashobotse gutangira kumva. Ikosa: $error';
  }

  @override
  String audioSelected(String fileName) {
    return 'Amajwi yatoranyijwe: $fileName';
  }

  @override
  String get audioTranscribed => 'Amajwi yanditswe neza!';

  @override
  String audioSelectionFailed(String error) {
    return 'Ikosa mu guhitamo amajwi: $error';
  }

  @override
  String get selectedAudioCouldNotBeRead =>
      'Dosiye y\'amajwi yatoranyijwe ntiyasomwe.';

  @override
  String get emptySpeechTranslationResponse =>
      'Igisubizo cy\'ubusemuzi bw\'ijwi kirimo ubusa.';

  @override
  String get translationCompleted => 'Ubusemuzi bwarangiye';

  @override
  String get recordVoice => 'Fata amajwi';

  @override
  String get uploadAudio => 'Ohereza amajwi';

  @override
  String get fromLanguage => 'Uvuye';

  @override
  String get toLanguage => 'Ujya';

  @override
  String get outputOptions => 'Uburyo bw\'igisubizo:';

  @override
  String get textOutput => '📝 Inyandiko';

  @override
  String get audioOutput => '🔊 Amajwi';

  @override
  String get bothOutputs => '📝🔊 Byombi';

  @override
  String get processingAudio => 'Birimo gutunganya amajwi...';

  @override
  String get convertingSpeechToText => 'Guhindura ijwi rikaba inyandiko';

  @override
  String get tapToStartRecording => 'Kanda utangire gufata amajwi';

  @override
  String confidence(String percentage) {
    return 'Icyizere: $percentage%';
  }

  @override
  String get recognizedSpeech => 'Ijwi ryumvikanye';

  @override
  String get shareComingSoon => 'Gusangiza abandi bizaza vuba!';

  @override
  String get recentTranslations => 'Ubusemuzi buheruka';

  @override
  String get liveTranslationTimedOut =>
      'Gusemura ako kanya byarengeje igihe. Ongera ugerageze ukoresheje videwo ngufi.';

  @override
  String get mediaPermissionPermanentlyDenied =>
      'Uruhushya rwa kamera cyangwa mikoro rwaranzwe burundu. Rwemerere mu igenamiterere rya porogaramu.';

  @override
  String get cameraMicrophonePermissionsRequired =>
      'Uruhushya rwa kamera na mikoro rurakenewe kugira ngo ufate videwo.';

  @override
  String get chooseVideoSource => 'Hitamo uko wongeramo videwo';

  @override
  String get recordVideo => 'Fata videwo';

  @override
  String get recordVideoDescription => 'Koresha kamera ufate videwo nshya';

  @override
  String get uploadVideoFromStorage =>
      'Ohereza videwo iri mu bubiko bwa telefoni';

  @override
  String get pickVideoDescription =>
      'Hitamo dosiye ya videwo iri kuri telefoni yawe';

  @override
  String get noVideoSelected => 'Nta dosiye ya videwo wahisemo.';

  @override
  String videoSelected(String filename) {
    return 'Wahisemo videwo: $filename';
  }

  @override
  String videoPickFailed(String error) {
    return 'Ntibyashobotse guhitamo dosiye ya videwo: $error';
  }

  @override
  String get noVideoRecorded => 'Nta videwo yafashwe.';

  @override
  String videoRecorded(String filename) {
    return 'Videwo yafashwe: $filename';
  }

  @override
  String videoRecordFailed(String error) {
    return 'Ntibyashobotse gufata videwo: $error';
  }

  @override
  String get noMediaSelected =>
      'Nta bikoresho by\'itangazamakuru byatoranyijwe';

  @override
  String get preparingLiveSubtitles =>
      'Turimo gutegura inyandiko z\'ubusemuzi bw\'ako kanya...';

  @override
  String get invalidTranslationResponse =>
      'Serivisi y\'ubusemuzi yatanze igisubizo kidateganyijwe.';

  @override
  String get translationComplete => 'Ubusemuzi burarangiye!';

  @override
  String mediaUploadFailed(String error) {
    return 'Kohereza iby\'itangazamakuru ntibyashobotse: $error';
  }

  @override
  String get enterYoutubeUrl => 'Andika aderesi ya YouTube';

  @override
  String get youtubeLiveTranslationFailed =>
      'Gusemura YouTube ako kanya ntibyashobotse';

  @override
  String youtubeLiveTranslationFailedWithError(String error) {
    return 'Gusemura YouTube ako kanya ntibyashobotse: $error';
  }

  @override
  String get noSpokenPhrasesDetected => 'Nta nteruro zavuzwe zabonetse.';

  @override
  String get liveSubtitlesReady =>
      'Inyandiko z\'ubusemuzi bw\'ako kanya ziriteguye.';

  @override
  String get liveTranslationFailed => 'Gusemura ako kanya ntibyashobotse';

  @override
  String get emptyMediaSummaryResponse =>
      'Igisubizo cy\'incamake y\'iby\'itangazamakuru nta kintu kirimo.';

  @override
  String get summaryComplete => 'Incamake irarangiye!';

  @override
  String mediaSummarizationFailed(String error) {
    return 'Gukora incamake y\'iby\'itangazamakuru ntibyashobotse: $error';
  }

  @override
  String get emptyYoutubeSummaryResponse =>
      'Igisubizo cy\'incamake ya YouTube nta kintu kirimo.';

  @override
  String youtubeSummarizationFailed(String error) {
    return 'Gukora incamake ya YouTube ntibyashobotse: $error';
  }

  @override
  String get selectOrRecordVideo => 'Banza uhitemo cyangwa ufate videwo.';

  @override
  String get enterYoutubeUrlOrSelectVideo =>
      'Andika aderesi ya YouTube cyangwa ubanze uhitemo videwo.';

  @override
  String get youtube => 'YouTube';

  @override
  String get video => 'Videwo';

  @override
  String get youtubeUrl => 'Aderesi ya YouTube';

  @override
  String get videoFile => 'Dosiye ya videwo';

  @override
  String get tapToSelectOrRecordVideo => 'Kanda uhitemo cyangwa ufate videwo';

  @override
  String get sourceLanguage => 'Ururimi rw\'inkomoko';

  @override
  String get targetLanguage => 'Ururimi rw\'ubusemuzi';

  @override
  String get auto => 'Byikora';

  @override
  String summaryForLanguage(String language) {
    return 'Incamake ($language):';
  }

  @override
  String get liveTranscript => 'Inyandiko ihinduka ako kanya:';

  @override
  String targetLanguageOnly(String language) {
    return 'Ururimi rwa $language gusa';
  }

  @override
  String get showBothLanguages => 'Erekana indimi zombi';

  @override
  String get stop => 'Hagarika';

  @override
  String get listen => 'Umva';

  @override
  String get studyTools => 'Ibikoresho byo kwiga';

  @override
  String get summarize => 'Gukora incamake';

  @override
  String get studyNotes => 'Inyandiko zo kwiga';

  @override
  String get notesSaved => 'Inyandiko zabitswe!';

  @override
  String get translateFirst => 'Banza usemure';

  @override
  String get vocabulary => 'Amagambo';

  @override
  String get keyVocabularyExtracted => 'Amagambo y\'ingenzi yatoranyijwe!';

  @override
  String get quiz => 'Ikizamini';

  @override
  String get quizGenerationComingSoon => 'Gukora ibizamini bizaboneka vuba!';

  @override
  String textToSpeechError(String error) {
    return 'Ikosa mu gusoma inyandiko mu ijwi: $error';
  }

  @override
  String translatedSpokenPhrases(int count) {
    return 'Interuro $count zavuzwe zasobanuwe...';
  }

  @override
  String get mediaContentContinues => 'Ibindi bikurikira...';

  @override
  String get nothingToPlay => 'Nta cyo kumva gihari. Banza usemure.';

  @override
  String unableToPlayAudio(String error) {
    return 'Ntibyashobotse gucuranga amajwi: $error';
  }

  @override
  String get noCameraFound => 'Nta kamera yabonetse kuri iki gikoresho.';

  @override
  String cameraOpenFailed(String error) {
    return 'Ntibyashobotse gufungura kamera: $error';
  }

  @override
  String videoRecordingFailed(String error) {
    return 'Gufata videwo ntibyashobotse: $error';
  }

  @override
  String get stopRecording => 'Hagarika gufata';

  @override
  String get startRecording => 'Tangira gufata';

  @override
  String get rwandaAfricaWorld => 'Rwanda • Afurika • Isi';

  @override
  String get developedByCompany =>
      'Byakozwe na Prime Data Consulting Group LTD';

  @override
  String get connectingPeople => 'Guhuza abantu';

  @override
  String get subtitlesGenerated => 'Inyandiko z\'amashusho zakozwe!';

  @override
  String get liveLocationActive => 'Aho uri hagaragazwa ako kanya!';

  @override
  String destinationSetTo(String location) {
    return 'Aho ujya hashyizwe kuri $location';
  }

  @override
  String get destinationSet => 'Aho ujya hashyizweho';

  @override
  String bestRouteSummary(String distance, String duration) {
    return 'Inzira nziza: km $distance, iminota $duration';
  }

  @override
  String get offlineDirectLine =>
      'Uburyo butari kuri interineti - umurongo ugororotse';
}
