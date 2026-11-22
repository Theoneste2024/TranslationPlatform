// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Mpuza - Rwanda';

  @override
  String get retry => 'Réessayer';

  @override
  String get continueToLogin => 'Continuer vers la connexion';

  @override
  String get selectLanguage => 'Choisir la langue';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageKinyarwanda => 'Kinyarwanda';

  @override
  String get languageFrench => 'Français';

  @override
  String languageUpdateFailed(String error) {
    return 'Impossible de changer la langue : $error';
  }

  @override
  String get openNavigationMenu => 'Ouvrir le menu de navigation';

  @override
  String get collapseSidebar => 'Réduire la barre latérale';

  @override
  String get home => 'Accueil';

  @override
  String get textTranslation => 'Traduction de texte';

  @override
  String get speechTranslation => 'Traduction vocale';

  @override
  String get videoTranslation => 'Traduction vidéo';

  @override
  String get cameraTranslation => 'Traduction par caméra';

  @override
  String get startTranslating => 'Commencer à traduire';

  @override
  String get educationTools => 'Outils éducatifs';

  @override
  String get underDevelopment => 'En cours de développement';

  @override
  String get offlinePacks => 'Packs hors ligne';

  @override
  String get driverMode => 'Mode conducteur';

  @override
  String get googleMaps => 'Google Maps';

  @override
  String get settings => 'Paramètres';

  @override
  String get about => 'À propos';

  @override
  String get aboutBlurb =>
      'Briser les barrières linguistiques au Rwanda, en Afrique et dans le monde.';

  @override
  String get supportedLanguages =>
      'Langues prises en charge : kinyarwanda, anglais et français.';

  @override
  String get madeWithPride => '🇷🇼 Fait avec fierté au Rwanda 🇷🇼';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get ok => 'OK';

  @override
  String get version => 'Version 1.0.0';

  @override
  String get settingsTitle => 'Paramètres de l’application';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get enableDarkTheme => 'Activer le thème sombre';

  @override
  String get defaultLanguage => 'Langue par défaut';

  @override
  String get speechRate => 'Vitesse de parole';

  @override
  String get normal => 'Normale';

  @override
  String get clearCache => 'Vider le cache';

  @override
  String cacheUsage(String size) {
    return '$size utilisés';
  }

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get loginToContinue => 'Connectez-vous pour continuer à traduire.';

  @override
  String get emailOrUsername => 'Adresse e-mail ou nom d’utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get enterPassword => 'Saisissez votre mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get login => 'Se connecter';

  @override
  String get newToMpuza => 'Nouveau sur MPUZA ? ';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get signupStepOne => 'ÉTAPE 1 SUR 2';

  @override
  String get joinMpuza =>
      'Rejoignez MPUZA et commencez à traduire dans plusieurs langues.';

  @override
  String get username => 'Nom d’utilisateur';

  @override
  String get emailAddress => 'Adresse e-mail';

  @override
  String get invalidEmailAddress => 'Saisissez une adresse e-mail valide';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte ? ';

  @override
  String get signupStepTwo => 'ÉTAPE 2 SUR 2';

  @override
  String get aboutYouAndSecurity => 'À propos de vous et sécurité';

  @override
  String get gender => 'Genre';

  @override
  String get male => 'Homme';

  @override
  String get female => 'Femme';

  @override
  String get preferNotToSay => 'Je préfère ne pas répondre';

  @override
  String get country => 'Pays';

  @override
  String get countryRwanda => 'Rwanda';

  @override
  String get countryBurundi => 'Burundi';

  @override
  String get countryDrCongo => 'République démocratique du Congo';

  @override
  String get countryKenya => 'Kenya';

  @override
  String get countryTanzania => 'Tanzanie';

  @override
  String get countryUganda => 'Ouganda';

  @override
  String get createStrongPassword => 'Créez un mot de passe robuste';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get reenterPassword => 'Saisissez à nouveau votre mot de passe';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get passwordsMatch => 'Les mots de passe correspondent';

  @override
  String get verifyYourEmail => 'Vérifiez votre adresse e-mail';

  @override
  String verificationCodeSentTo(String email) {
    return 'Nous avons envoyé un code à 6 chiffres à\n$email';
  }

  @override
  String get codeExpiresInPrefix => 'Le code expire dans ';

  @override
  String get didntGetIt => 'Vous ne l’avez pas reçu ? ';

  @override
  String resendIn(String duration) {
    return 'Renvoyer dans $duration';
  }

  @override
  String get resendCode => 'Renvoyer le code';

  @override
  String get verify => 'Vérifier';

  @override
  String get wrongEmail => 'Mauvaise adresse e-mail ? ';

  @override
  String get changeIt => 'La modifier';

  @override
  String get emailVerified => 'E-mail vérifié !';

  @override
  String get accountReadyMessage =>
      'Votre compte MPUZA est prêt. Connectez-vous avec votre adresse e-mail ou votre nom d’utilisateur pour commencer à traduire.';

  @override
  String get goToLogin => 'Aller à la connexion';

  @override
  String get forgotPasswordInstructions =>
      'Saisissez l’adresse e-mail associée à votre compte MPUZA. Nous vous enverrons un code de réinitialisation.';

  @override
  String get sendResetCode => 'Envoyer le code de réinitialisation';

  @override
  String get rememberPassword => 'Vous vous souvenez de votre mot de passe ? ';

  @override
  String get resetYourPassword => 'Réinitialiser votre mot de passe';

  @override
  String resetCodeSentTo(String email) {
    return 'Saisissez le code envoyé à\n$email';
  }

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get confirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get resetPassword => 'Réinitialiser le mot de passe';

  @override
  String get back => 'Retour';

  @override
  String get weak => 'Faible';

  @override
  String get fair => 'Moyen';

  @override
  String get strong => 'Fort';

  @override
  String get passwordStrength => 'Robustesse du mot de passe';

  @override
  String get eightPlusCharacters => '8 caractères ou plus';

  @override
  String get uppercase => 'Majuscule';

  @override
  String get lowercase => 'Minuscule';

  @override
  String get numberAndSymbol => 'Chiffre et symbole';

  @override
  String get requiredField => 'Ce champ est obligatoire';

  @override
  String get passwordStrengthRequirement =>
      'Utilisez au moins 8 caractères avec une majuscule, une minuscule, un chiffre et un symbole';

  @override
  String get selectGender => 'Sélectionnez une option de genre pour continuer.';

  @override
  String get enterSixDigitCode =>
      'Saisissez le code à 6 chiffres pour continuer.';

  @override
  String get passwordResetComplete =>
      'Mot de passe réinitialisé. Vous pouvez maintenant vous connecter.';

  @override
  String get translationSuccessful => 'Traduction réussie';

  @override
  String get translationTimedOut =>
      'La traduction prend plus de temps que prévu. Veuillez réessayer.';

  @override
  String translationFailed(String error) {
    return 'Échec de la traduction : $error';
  }

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers !';

  @override
  String get removedFromFavorites => 'Retiré des favoris !';

  @override
  String get savedToFavorites => 'Ajouté aux favoris !';

  @override
  String get sourceText => 'Texte source';

  @override
  String get sourceTextHint => 'Saisissez le texte à traduire...';

  @override
  String characterCount(int count) {
    return '$count caractères';
  }

  @override
  String get translating => 'Traduction en cours...';

  @override
  String get translate => 'Traduire';

  @override
  String get translation => 'Traduction';

  @override
  String get translationPlaceholder => 'La traduction apparaîtra ici';

  @override
  String get cameraPermissionRequired =>
      'L’autorisation d’utiliser la caméra est requise';

  @override
  String get noTextFoundInImage => 'Aucun texte trouvé dans l’image';

  @override
  String imageProcessingFailed(String error) {
    return 'Erreur lors du traitement de l’image : $error';
  }

  @override
  String imageTranslationFailed(String error) {
    return 'Erreur lors de la traduction du texte : $error';
  }

  @override
  String get takeOrUploadImage => 'Prendre ou importer une image';

  @override
  String get takeRearPhoto => 'Prendre une photo (arrière)';

  @override
  String get takeFrontPhoto => 'Prendre une photo (avant)';

  @override
  String get uploadPhoto => 'Importer une photo';

  @override
  String get offlineTranslationPacks => 'Packs de traduction hors ligne';

  @override
  String get deviceStorage => 'Stockage de l’appareil';

  @override
  String storageUsage(String used, String free) {
    return '$used utilisés • $free disponibles';
  }

  @override
  String get myPacks => 'Mes packs';

  @override
  String get viewAll => 'Tout afficher';

  @override
  String get free => 'Gratuit';

  @override
  String get downloaded => 'Téléchargé';

  @override
  String get download => 'Télécharger';

  @override
  String downloadingPack(String pack) {
    return 'Téléchargement de $pack...';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get basicKinyarwandaPack => 'Pack de base en kinyarwanda';

  @override
  String get essentialPhrasesDescription =>
      'Expressions essentielles et vocabulaire courant';

  @override
  String get completeKinyarwandaPack => 'Pack complet en kinyarwanda';

  @override
  String get completeDictionaryDescription =>
      'Dictionnaire complet kinyarwanda-anglais-français';

  @override
  String get motoristCommunicationPack =>
      'Pack de communication pour conducteurs';

  @override
  String get transportationPhrasesDescription =>
      'Expressions pour le transport et la navigation';

  @override
  String get medicalEmergencyPack => 'Pack médical et d’urgence';

  @override
  String get healthcareVocabularyDescription =>
      'Vocabulaire de santé et d’urgence';

  @override
  String get educationPack => 'Pack éducatif';

  @override
  String get academicVocabularyDescription =>
      'Vocabulaire et terminologie académiques';

  @override
  String get tourismHospitalityPack => 'Pack tourisme et hôtellerie';

  @override
  String get tourismPhrasesDescription =>
      'Expressions touristiques et de service';

  @override
  String get lectureSummarizer => 'Résumé de cours';

  @override
  String get comingSoon => 'Bientôt disponible !';

  @override
  String get autoSummarizeLectures => 'Résumé automatique des cours';

  @override
  String get studyNotesGeneration => 'Génération de notes de cours';

  @override
  String get vocabularyExtraction => 'Extraction de vocabulaire';

  @override
  String get backToHome => 'Retour à l’accueil';

  @override
  String get motoristModeActive => 'Mode conducteur actif';

  @override
  String get listeningForCommands => 'À l’écoute des commandes...';

  @override
  String get tapToActivate => 'Touchez pour activer';

  @override
  String get navigate => 'Naviguer';

  @override
  String get fare => 'Tarif';

  @override
  String get call => 'Appeler';

  @override
  String get currentlyNavigating => 'Navigation en cours';

  @override
  String get readyForPassengers => 'Prêt à accueillir des passagers';

  @override
  String get followTheRoute => 'Suivez l’itinéraire';

  @override
  String get tapToStartNavigation => 'Touchez pour démarrer la navigation';

  @override
  String get voiceCommands => 'Commandes vocales';

  @override
  String get listening => 'Écoute en cours...';

  @override
  String get tapToSpeak => 'Touchez pour parler';

  @override
  String get enableLocationServices =>
      'Veuillez activer les services de localisation';

  @override
  String get locationPermissionDenied => 'Autorisation de localisation refusée';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Autorisation de localisation définitivement refusée';

  @override
  String get showingKigaliCenter => 'Centre de Kigali affiché';

  @override
  String get placeSearchFailed => 'Échec de la recherche. Veuillez réessayer.';

  @override
  String get noPhoneAvailable => 'Aucun numéro de téléphone disponible';

  @override
  String placeCategory(String category) {
    return '$category';
  }

  @override
  String get freeGeocodingNoApiKey => 'Géocodage gratuit, sans clé API';

  @override
  String get close => 'Fermer';

  @override
  String get navigateHere => 'Naviguer ici';

  @override
  String get selectedLocation => 'Lieu sélectionné';

  @override
  String get setDestinationFirst => 'Veuillez d’abord définir une destination';

  @override
  String headDirection(String direction) {
    return 'Dirigez-vous vers $direction';
  }

  @override
  String get north => 'le nord';

  @override
  String get south => 'le sud';

  @override
  String get east => 'l’est';

  @override
  String get west => 'l’ouest';

  @override
  String get northeast => 'le nord-est';

  @override
  String get northwest => 'le nord-ouest';

  @override
  String get southeast => 'le sud-est';

  @override
  String get southwest => 'le sud-ouest';

  @override
  String get offlineDirectRoute => 'Itinéraire hors ligne (ligne directe)';

  @override
  String get freeMapsRwanda => '🗺️ Cartes gratuites - Rwanda';

  @override
  String get liveLocationFreeGeocoding =>
      'Position en direct • géocodage gratuit';

  @override
  String get hideNearbyPlaces => 'Masquer les lieux à proximité';

  @override
  String get myLocation => 'Ma position';

  @override
  String get gettingLiveLocation => 'Récupération de votre position...';

  @override
  String get zoomIn => 'Zoom avant';

  @override
  String get zoomOut => 'Zoom arrière';

  @override
  String get searchPlaceHint => 'Rechercher un lieu au Rwanda...';

  @override
  String get nearbyPlaces => 'Lieux à proximité';

  @override
  String get bestRoute => 'Meilleur itinéraire';

  @override
  String get destination => 'Destination';

  @override
  String minutesAbbreviation(String minutes) {
    return '$minutes min';
  }

  @override
  String get distance => 'Distance';

  @override
  String get travelMode => 'Mode de déplacement';

  @override
  String get summary => 'Résumé';

  @override
  String get routeReady => 'Itinéraire prêt';

  @override
  String get setDestination => 'Définir la destination';

  @override
  String get getDirections => 'Obtenir l’itinéraire';

  @override
  String get clearRoute => 'Effacer l’itinéraire';

  @override
  String get hospitals => 'Hôpitaux';

  @override
  String get hotels => 'Hôtels';

  @override
  String get restaurants => 'Restaurants';

  @override
  String get coffeeShops => 'Cafés';

  @override
  String get bars => 'Bars';

  @override
  String get car => 'Voiture';

  @override
  String get walk => 'À pied';

  @override
  String get bicycle => 'Vélo';

  @override
  String get microphonePermissionRequired =>
      'L’accès au microphone est nécessaire pour la reconnaissance vocale';

  @override
  String get noSpeechDetected =>
      'Aucune voix détectée. Parlez clairement et réessayez.';

  @override
  String get microphonePermissionDenied => 'Accès au microphone refusé';

  @override
  String get speechRecognitionError => 'Erreur de reconnaissance vocale';

  @override
  String get speechRecognitionUnavailable =>
      'La reconnaissance vocale n’est pas disponible. Autorisez l’accès au microphone puis réessayez.';

  @override
  String get couldNotStartListening =>
      'Impossible de démarrer l’écoute. Autorisez l’accès au microphone puis réessayez.';

  @override
  String get browserMicrophonePermissionRequired =>
      'Autorisation du microphone requise : utilisez l’icône de cadenas dans la barre d’adresse pour autoriser le microphone.';

  @override
  String get noMicrophoneDetected =>
      'Aucun microphone détecté. Veuillez en connecter un.';

  @override
  String get microphoneReady => 'Microphone prêt. Parlez clairement.';

  @override
  String couldNotStartListeningWithError(String error) {
    return 'Impossible de démarrer l’écoute. Erreur : $error';
  }

  @override
  String audioSelected(String fileName) {
    return 'Audio sélectionné : $fileName';
  }

  @override
  String get audioTranscribed => 'Audio transcrit avec succès !';

  @override
  String audioSelectionFailed(String error) {
    return 'Erreur lors de la sélection de l’audio : $error';
  }

  @override
  String get selectedAudioCouldNotBeRead =>
      'Le fichier audio sélectionné n’a pas pu être lu.';

  @override
  String get emptySpeechTranslationResponse =>
      'La réponse de traduction vocale est vide.';

  @override
  String get translationCompleted => 'Traduction terminée';

  @override
  String get recordVoice => 'Enregistrer la voix';

  @override
  String get uploadAudio => 'Importer un fichier audio';

  @override
  String get fromLanguage => 'De';

  @override
  String get toLanguage => 'Vers';

  @override
  String get outputOptions => 'Options de sortie :';

  @override
  String get textOutput => '📝 Texte';

  @override
  String get audioOutput => '🔊 Audio';

  @override
  String get bothOutputs => '📝🔊 Les deux';

  @override
  String get processingAudio => 'Traitement de l’audio...';

  @override
  String get convertingSpeechToText => 'Conversion de la voix en texte';

  @override
  String get tapToStartRecording => 'Touchez pour commencer l’enregistrement';

  @override
  String confidence(String percentage) {
    return 'Confiance : $percentage %';
  }

  @override
  String get recognizedSpeech => 'Parole reconnue';

  @override
  String get shareComingSoon => 'Le partage sera bientôt disponible !';

  @override
  String get recentTranslations => 'Traductions récentes';

  @override
  String get liveTranslationTimedOut =>
      'La traduction en direct a expiré. Réessayez avec une vidéo plus courte.';

  @override
  String get mediaPermissionPermanentlyDenied =>
      'L’accès à la caméra ou au microphone est définitivement refusé. Activez-le dans les paramètres de l’application.';

  @override
  String get cameraMicrophonePermissionsRequired =>
      'Les autorisations de la caméra et du microphone sont nécessaires pour enregistrer une vidéo.';

  @override
  String get chooseVideoSource => 'Choisissez comment ajouter votre vidéo';

  @override
  String get recordVideo => 'Enregistrer une vidéo';

  @override
  String get recordVideoDescription =>
      'Utilisez votre caméra pour filmer une nouvelle vidéo';

  @override
  String get uploadVideoFromStorage =>
      'Importer une vidéo depuis le stockage local';

  @override
  String get pickVideoDescription => 'Choisissez une vidéo sur votre appareil';

  @override
  String get noVideoSelected => 'Aucun fichier vidéo n’a été sélectionné.';

  @override
  String videoSelected(String filename) {
    return 'Vidéo sélectionnée : $filename';
  }

  @override
  String videoPickFailed(String error) {
    return 'Impossible de sélectionner la vidéo : $error';
  }

  @override
  String get noVideoRecorded => 'Aucune vidéo n’a été enregistrée.';

  @override
  String videoRecorded(String filename) {
    return 'Vidéo enregistrée : $filename';
  }

  @override
  String videoRecordFailed(String error) {
    return 'Impossible d’enregistrer la vidéo : $error';
  }

  @override
  String get noMediaSelected => 'Aucun média sélectionné';

  @override
  String get preparingLiveSubtitles =>
      'Préparation des sous-titres traduits en direct...';

  @override
  String get invalidTranslationResponse =>
      'Format de réponse inattendu du service de traduction.';

  @override
  String get translationComplete => 'Traduction terminée !';

  @override
  String mediaUploadFailed(String error) {
    return 'Échec de l’envoi du média : $error';
  }

  @override
  String get enterYoutubeUrl => 'Saisissez une URL YouTube';

  @override
  String get youtubeLiveTranslationFailed =>
      'Échec de la traduction YouTube en direct';

  @override
  String youtubeLiveTranslationFailedWithError(String error) {
    return 'Échec de la traduction YouTube en direct : $error';
  }

  @override
  String get noSpokenPhrasesDetected =>
      'Aucune phrase prononcée n’a été détectée.';

  @override
  String get liveSubtitlesReady => 'Les sous-titres en direct sont prêts.';

  @override
  String get liveTranslationFailed => 'Échec de la traduction en direct';

  @override
  String get emptyMediaSummaryResponse =>
      'La réponse du résumé du média était vide.';

  @override
  String get summaryComplete => 'Résumé terminé !';

  @override
  String mediaSummarizationFailed(String error) {
    return 'Échec du résumé du média : $error';
  }

  @override
  String get emptyYoutubeSummaryResponse =>
      'La réponse du résumé YouTube était vide.';

  @override
  String youtubeSummarizationFailed(String error) {
    return 'Échec du résumé YouTube : $error';
  }

  @override
  String get selectOrRecordVideo =>
      'Sélectionnez ou enregistrez d’abord une vidéo.';

  @override
  String get enterYoutubeUrlOrSelectVideo =>
      'Saisissez une URL YouTube ou sélectionnez d’abord une vidéo.';

  @override
  String get youtube => 'YouTube';

  @override
  String get video => 'Vidéo';

  @override
  String get youtubeUrl => 'URL YouTube';

  @override
  String get videoFile => 'Fichier vidéo';

  @override
  String get tapToSelectOrRecordVideo =>
      'Touchez pour sélectionner ou enregistrer une vidéo';

  @override
  String get sourceLanguage => 'Langue source';

  @override
  String get targetLanguage => 'Langue cible';

  @override
  String get auto => 'Automatique';

  @override
  String summaryForLanguage(String language) {
    return 'Résumé ($language) :';
  }

  @override
  String get liveTranscript => 'Transcription en direct :';

  @override
  String targetLanguageOnly(String language) {
    return '$language uniquement';
  }

  @override
  String get showBothLanguages => 'Afficher les deux langues';

  @override
  String get stop => 'Arrêter';

  @override
  String get listen => 'Écouter';

  @override
  String get studyTools => 'Outils d’étude';

  @override
  String get summarize => 'Résumer';

  @override
  String get studyNotes => 'Notes d’étude';

  @override
  String get notesSaved => 'Notes enregistrées !';

  @override
  String get translateFirst => 'Traduisez d’abord';

  @override
  String get vocabulary => 'Vocabulaire';

  @override
  String get keyVocabularyExtracted => 'Vocabulaire clé extrait !';

  @override
  String get quiz => 'Quiz';

  @override
  String get quizGenerationComingSoon =>
      'La génération de quiz sera bientôt disponible !';

  @override
  String textToSpeechError(String error) {
    return 'Erreur de synthèse vocale : $error';
  }

  @override
  String translatedSpokenPhrases(int count) {
    return '$count phrases orales traduites...';
  }

  @override
  String get mediaContentContinues => 'La suite du contenu...';

  @override
  String get nothingToPlay => 'Rien à écouter. Traduisez d’abord.';

  @override
  String unableToPlayAudio(String error) {
    return 'Impossible de lire l’audio : $error';
  }

  @override
  String get noCameraFound => 'Aucune caméra n’a été trouvée sur cet appareil.';

  @override
  String cameraOpenFailed(String error) {
    return 'Impossible d’ouvrir la caméra : $error';
  }

  @override
  String videoRecordingFailed(String error) {
    return 'Échec de l’enregistrement : $error';
  }

  @override
  String get stopRecording => 'Arrêter l’enregistrement';

  @override
  String get startRecording => 'Commencer l’enregistrement';

  @override
  String get rwandaAfricaWorld => 'Rwanda • Afrique • Monde';

  @override
  String get developedByCompany =>
      'Développé par Prime Data Consulting Group LTD';

  @override
  String get connectingPeople => 'Connecter les personnes';

  @override
  String get subtitlesGenerated => 'Sous-titres générés !';

  @override
  String get liveLocationActive => 'Position en direct activée !';

  @override
  String destinationSetTo(String location) {
    return 'Destination définie sur $location';
  }

  @override
  String get destinationSet => 'Destination définie';

  @override
  String bestRouteSummary(String distance, String duration) {
    return 'Meilleur itinéraire : $distance km, $duration min';
  }

  @override
  String get offlineDirectLine => 'Mode hors ligne - ligne directe';
}
