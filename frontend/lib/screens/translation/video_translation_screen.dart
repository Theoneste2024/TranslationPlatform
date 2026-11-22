// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:omni_video_player/omni_video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../l10n/app_localizations_extensions.dart';
import '../../core/network/api_config.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/app_header.dart';

Map<String, dynamic> normalizeVideoTranslationPayload(
    Map<String, dynamic> payload) {
  final dynamic segmentsValue = payload['segments'];
  final segments = <Map<String, dynamic>>[];
  String stringValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  if (segmentsValue is List) {
    for (final item in segmentsValue) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final original = stringValue(map['original'] ?? map['text'] ?? '');
      final translated =
          stringValue(map['translated'] ?? map['translation'] ?? '');
      if (original.isEmpty && translated.isEmpty) continue;

      final start = (map['start'] as num?)?.toDouble() ?? 0.0;
      final end = (map['end'] as num?)?.toDouble() ?? start + 3.0;
      segments.add({
        'startSeconds': start,
        'endSeconds': end,
        'start': _formatSubtitleTimeForPayload(start),
        'end': _formatSubtitleTimeForPayload(end),
        'original': original,
        'translated': translated,
      });
    }
  }

  if (segments.isNotEmpty) {
    return {
      'originalTranscript':
          segments.map((segment) => segment['original']).join(' '),
      'translatedText':
          segments.map((segment) => segment['translated']).join(' '),
      'subtitles': segments,
      'summaryText': '',
      'summaryLanguageName': '',
      'liveSubtitleText': '',
      'currentSubtitleIndex': -1,
      'liveStatus': '',
    };
  }

  return {
    'originalTranscript': stringValue(payload['original_text'] ??
        payload['originalText'] ??
        payload['transcript'] ??
        payload['transcript_text']),
    'translatedText': stringValue(payload['translated_text'] ??
        payload['translatedText'] ??
        payload['translation'] ??
        payload['translated']),
    'subtitles': <Map<String, dynamic>>[],
    'summaryText': '',
    'summaryLanguageName': '',
    'liveSubtitleText': '',
    'currentSubtitleIndex': -1,
    'liveStatus': '',
  };
}

String _formatSubtitleTimeForPayload(double seconds) {
  final duration = Duration(milliseconds: (seconds * 1000).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$secs';
  }
  return '$minutes:$secs';
}

class VideoTranslationScreen extends StatefulWidget {
  const VideoTranslationScreen({super.key});

  @override
  State<VideoTranslationScreen> createState() => _VideoTranslationScreenState();
}

class _VideoTranslationScreenState extends State<VideoTranslationScreen> {
  // Controllers
  final TextEditingController _urlController = TextEditingController();
  final ScrollController _subtitleScrollController = ScrollController();

  // Video Players
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  OmniPlaybackController? _youtubeController;
  StreamSubscription<String>? _liveTranslationSubscription;
  Timer? _liveTranslationWatchdog;

  // --- Playback sync ---
  // omni_video_player's own docs describe its controller as notifying
  // listeners on discrete STATE changes (play/pause/buffering) — there is
  // no onPositionChanged/onProgress callback in its API. That means
  // `currentPosition` may only be reliable at those discrete moments, not
  // continuously while the video is simply playing. Rather than keep
  // trusting a getter that may not update between those moments, we keep
  // our own clock: read the package's position once at each discrete event
  // (play/pause/seek — the moments its docs say ARE accurate), then advance
  // locally using wall-clock time in between. This can't be thrown off by
  // the package's internal update cadence.
  final Stopwatch _playbackClock = Stopwatch();
  double _playbackBaselineSeconds = 0;
  bool _wasPlaying = false;
  Timer? _positionPollTimer;
  static const Duration _positionPollInterval = Duration(milliseconds: 300);

  double _currentEstimatedSeconds() {
    final elapsed = _playbackClock.isRunning
        ? _playbackClock.elapsed.inMilliseconds / 1000.0
        : 0.0;
    return _playbackBaselineSeconds + elapsed;
  }

  // Called from the controller's own listener whenever ANY state change is
  // reported (play, pause, buffering, etc.) — this is the moment the
  // package's docs say its internal state (including position) is fresh.
  void _onControllerStateChanged() {
    final controller = _youtubeController;
    if (controller == null) return;
    final isPlaying = controller.isPlaying;

    if (isPlaying && !_wasPlaying) {
      // Just started/resumed — resync our baseline from the package's
      // reported position at this trustworthy moment, then start our own
      // clock running from here.
      final reportedSeconds =
          controller.currentPosition.inMilliseconds / 1000.0;
      _playbackBaselineSeconds = reportedSeconds;
      _playbackClock
        ..reset()
        ..start();
    } else if (!isPlaying && _wasPlaying) {
      // Just paused — freeze our estimate exactly where it is.
      _playbackBaselineSeconds = _currentEstimatedSeconds();
      _playbackClock.stop();
    }
    _wasPlaying = isPlaying;
  }

  // Single listener callback registered on the controller: updates our
  // local clock's baseline on state changes, then re-syncs captions.
  void _handleControllerNotification() {
    _onControllerStateChanged();
    _syncLiveSubtitleToPlayback();
  }

  // Every setState in this widget (including the ones fired for each
  // incoming live-translation segment) reruns build(). If the
  // VideoPlayerConfiguration passed to OmniVideoPlayer is constructed fresh
  // inline every build, its object identity changes on every rebuild even
  // though the URL is the same — and player widgets commonly reinitialize
  // (or otherwise lose their internal state/position tracking) when their
  // configuration object identity changes. Since new segments arrive
  // continuously while the video is playing, this can happen dozens of
  // times during playback, which is consistent with "the transcript never
  // catches up to the video." Caching the configuration by URL keeps the
  // same object across rebuilds so the player is left alone.
  VideoPlayerConfiguration? _youtubeConfigCache;
  String? _youtubeConfigCacheUrl;

  VideoPlayerConfiguration _youtubeConfigFor(String url) {
    if (_youtubeConfigCache != null && _youtubeConfigCacheUrl == url) {
      return _youtubeConfigCache!;
    }
    _youtubeConfigCache = VideoPlayerConfiguration(
      videoSourceConfiguration: VideoSourceConfiguration.youtube(
        videoUrl: Uri.parse(url),
      ),
    );
    _youtubeConfigCacheUrl = url;
    return _youtubeConfigCache!;
  }

  // UI States
  final bool _isLoading = false;
  bool _isTranslating = false;
  bool _isSummarizing = false;

  // Language Selection
  String _sourceLanguage = 'auto';
  String _targetLanguage = 'en';
  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'rw', 'name': 'Kinyarwanda', 'flag': '🇷🇼'},
  ];

  // Transcription & Translation
  String _originalTranscript = '';
  String _translatedText = '';
  String _summaryText = '';
  String _summaryLanguageName = '';
  List<Map<String, dynamic>> _subtitles = [];
  String _liveSubtitleText = '';
  String _liveStatus = '';
  int _liveTranslationRunId = 0;
  final List<GlobalKey> _subtitleKeys = [];
  int _currentSubtitleIndex = -1;
  bool _showBothLanguages = false;
  static const Duration _liveTranslationIdleTimeout = Duration(minutes: 3);

  // Media Source Type
  String _videoSource = 'youtube';
  File? _selectedMediaFile;
  Uint8List? _selectedMediaBytes;
  String? _selectedMediaFileName;
  String? _mediaType; // 'youtube', 'video'
  // Text-to-speech
  late final FlutterTts _flutterTts;
  bool _isPlayingSound = false;
  // Hover states for chips
  bool _hoverYouTube = false;
  bool _hoverVideo = false;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _flutterTts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _isPlayingSound = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isPlayingSound = false);
    });
    _flutterTts.setErrorHandler((err) {
      if (!mounted) return;
      setState(() => _isPlayingSound = false);
      _showSnackBar(context.l10n.textToSpeechError(err.toString()), Colors.red);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _subtitleScrollController.dispose();
    _liveTranslationSubscription?.cancel();
    _liveTranslationWatchdog?.cancel();
    _positionPollTimer?.cancel();
    _youtubeController?.removeListener(_handleControllerNotification);
    _videoController?.removeListener(_handleLocalControllerNotification);
    _flutterTts.stop();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _resetLiveTranslationWatchdog(int runId) {
    _liveTranslationWatchdog?.cancel();
    _liveTranslationWatchdog = Timer(_liveTranslationIdleTimeout, () {
      if (!mounted || runId != _liveTranslationRunId || !_isTranslating) return;
      _liveTranslationSubscription?.cancel();
      setState(() {
        _isTranslating = false;
        _liveStatus = context.l10n.liveTranslationTimedOut;
      });
      _showSnackBar(
        context.l10n.liveTranslationTimedOut,
        Colors.red,
      );
    });
  }

  void _stopLiveTranslationWatchdog() {
    _liveTranslationWatchdog?.cancel();
    _liveTranslationWatchdog = null;
  }

  // Starts the polling loop that keeps captions/transcript in sync with
  // whatever the video is actually doing right now. Safe to call repeatedly.
  void _startPositionPolling() {
    _positionPollTimer?.cancel();
    _positionPollTimer = Timer.periodic(_positionPollInterval, (_) {
      _syncLiveSubtitleToPlayback();
    });
  }

  void _stopPositionPolling() {
    _positionPollTimer?.cancel();
    _positionPollTimer = null;
  }

  void _attachLocalVideoController(VideoPlayerController controller) {
    controller.addListener(_handleLocalControllerNotification);
    _startPositionPolling();
  }

  void _handleLocalControllerNotification() {
    _syncLiveSubtitleToPlayback();
  }

  void _setVideoSource(String source) {
    _stopPositionPolling();
    _youtubeConfigCache = null;
    _youtubeConfigCacheUrl = null;
    setState(() {
      _videoSource = source;
      _urlController.clear();
      _selectedMediaFile = null;
      _selectedMediaBytes = null;
      _selectedMediaFileName = null;
      _videoController?.dispose();
      _chewieController?.dispose();
      _liveTranslationSubscription?.cancel();
      _youtubeController?.removeListener(_handleControllerNotification);
      _videoController?.removeListener(_handleLocalControllerNotification);
      _youtubeController = null;
      _videoController = null;
      _chewieController = null;
      _playbackClock.stop();
      _playbackBaselineSeconds = 0;
      _wasPlaying = false;
      _originalTranscript = '';
      _translatedText = '';
      _summaryText = '';
      _summaryLanguageName = '';
      _liveSubtitleText = '';
      _liveStatus = '';
      _subtitles.clear();
      _subtitleKeys.clear();
      _currentSubtitleIndex = -1;
      _mediaType = null;
    });
  }

  Future<bool> _requestVideoRecordingPermissions() async {
    if (kIsWeb) {
      return true;
    }

    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;
    if (cameraStatus.isGranted && microphoneStatus.isGranted) {
      return true;
    }

    if (cameraStatus.isPermanentlyDenied ||
        microphoneStatus.isPermanentlyDenied) {
      _showSnackBar(
          context.l10n.mediaPermissionPermanentlyDenied, Colors.orange);
      return false;
    }

    final requested = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    if (requested[Permission.camera]?.isGranted == true &&
        requested[Permission.microphone]?.isGranted == true) {
      return true;
    }

    _showSnackBar(
        context.l10n.cameraMicrophonePermissionsRequired, Colors.orange);
    return false;
  }

  Future<void> _showVideoSourcePicker() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.chooseVideoSource,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.blue),
                  title: Text(context.l10n.recordVideo),
                  subtitle: Text(context.l10n.recordVideoDescription),
                  onTap: () async {
                    Navigator.pop(context);
                    await _recordVideo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.green),
                  title: Text(context.l10n.uploadVideoFromStorage),
                  subtitle: Text(context.l10n.pickVideoDescription),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideoFile();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickVideoFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        _showSnackBar(context.l10n.noVideoSelected, Colors.orange);
        return;
      }

      final picked = result.files.single;
      if (picked.bytes != null) {
        setState(() {
          _selectedMediaBytes = picked.bytes;
          _selectedMediaFileName = picked.name;
          _selectedMediaFile = null;
          _mediaType = 'video';
          _videoSource = 'file';
        });
      } else if (picked.path != null) {
        setState(() {
          _selectedMediaFile = File(picked.path!);
          _selectedMediaBytes = null;
          _selectedMediaFileName = picked.name;
          _mediaType = 'video';
          _videoSource = 'file';
        });
      }
      if (_selectedMediaFile != null) {
        _initializeLocalVideoPlayer(_selectedMediaFile!);
      }
      _showSnackBar(context.l10n.videoSelected(picked.name), Colors.green);
    } catch (e) {
      _showSnackBar(context.l10n.videoPickFailed(e.toString()), Colors.red);
    }
  }

  Future<void> _recordVideo() async {
    try {
      final hasPermission = await _requestVideoRecordingPermissions();
      if (!hasPermission) {
        return;
      }

      final navigator = Navigator.of(context);
      final XFile? video = await navigator.push<XFile>(
        MaterialPageRoute(
          builder: (_) => const _VideoRecorderScreen(),
        ),
      );
      if (video == null) {
        _showSnackBar(context.l10n.noVideoRecorded, Colors.orange);
        return;
      }

      final recordedFileName = _videoUploadFileName(video);
      if (kIsWeb) {
        final bytes = await video.readAsBytes();
        setState(() {
          _selectedMediaBytes = bytes;
          _selectedMediaFileName = recordedFileName;
          _selectedMediaFile = null;
          _mediaType = 'video';
          _videoSource = 'file';
        });
      } else if (video.path.isNotEmpty) {
        setState(() {
          _selectedMediaFile = File(video.path);
          _selectedMediaBytes = null;
          _selectedMediaFileName = recordedFileName;
          _mediaType = 'video';
          _videoSource = 'file';
        });
      }

      if (_selectedMediaFile != null) {
        _initializeLocalVideoPlayer(_selectedMediaFile!);
      }

      _showSnackBar(context.l10n.videoRecorded(video.name), Colors.green);
    } catch (e) {
      _showSnackBar(context.l10n.videoRecordFailed(e.toString()), Colors.red);
    }
  }

  String _videoUploadFileName(XFile video) {
    final pathName = video.path.isNotEmpty ? p.basename(video.path) : '';
    final rawName = video.name.isNotEmpty ? video.name : pathName;
    final rawExtension = p.extension(rawName);
    if (rawExtension.isNotEmpty) {
      return rawName;
    }

    final pathExtension = p.extension(pathName);
    if (pathExtension.isNotEmpty) {
      return '$rawName$pathExtension';
    }

    return 'recorded_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
  }

  Future<void> _initializeLocalVideoPlayer(File file) async {
    if (!mounted) return;

    _videoController?.dispose();
    _chewieController?.dispose();

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    final chewieController = ChewieController(
      videoPlayerController: controller,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      allowPlaybackSpeedChanging: true,
    );

    if (!mounted) {
      chewieController.dispose();
      await controller.dispose();
      return;
    }

    setState(() {
      _videoController = controller;
      _chewieController = chewieController;
      _mediaType = 'video';
    });
    _attachLocalVideoController(controller);
  }

  Future<void> _uploadMedia(
      {File? file, Uint8List? bytes, String? filename}) async {
    if (file == null && bytes == null) {
      _showSnackBar(context.l10n.noMediaSelected, Colors.orange);
      return;
    }

    final apiClient = context.read<ApiClient>();
    final runId = ++_liveTranslationRunId;
    await _liveTranslationSubscription?.cancel();
    _stopLiveTranslationWatchdog();
    setState(() {
      _isTranslating = true;
      _mediaType = 'video';
      _originalTranscript = '';
      _translatedText = '';
      _summaryText = '';
      _summaryLanguageName = '';
      _liveSubtitleText = '';
      _liveStatus = context.l10n.preparingLiveSubtitles;
      _subtitles.clear();
      _subtitleKeys.clear();
      _currentSubtitleIndex = -1;
    });
    _resetLiveTranslationWatchdog(runId);

    try {
      final formData = FormData.fromMap({
        'source_language': _sourceLanguage,
        'target_language': _targetLanguage,
      });

      if (bytes != null) {
        formData.files.add(
          MapEntry(
            'video',
            MultipartFile.fromBytes(
              bytes,
              filename: filename ?? 'media.bin',
            ),
          ),
        );
      } else if (file != null) {
        formData.files.add(
          MapEntry(
            'video',
            await MultipartFile.fromFile(
              file.path,
              filename: filename ?? p.basename(file.path),
            ),
          ),
        );
      }

      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'analyze_video/',
        data: formData,
      );
      final data = response.data;
      if (data == null) {
        throw Exception(context.l10n.invalidTranslationResponse);
      }
      _applyTranslationPayload(data);
      _showSnackBar(context.l10n.translationComplete, Colors.green);
    } catch (e) {
      _showSnackBar(context.l10n.mediaUploadFailed(e.toString()), Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  // Translate a YouTube URL by streaming timestamped subtitle segments from the backend.
  Future<void> _translateYouTubeUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar(context.l10n.enterYoutubeUrl, Colors.orange);
      return;
    }

    final apiClient = context.read<ApiClient>();
    final runId = ++_liveTranslationRunId;
    await _liveTranslationSubscription?.cancel();
    setState(() {
      _isTranslating = true;
      _mediaType = 'youtube';
      _originalTranscript = '';
      _translatedText = '';
      _summaryText = '';
      _summaryLanguageName = '';
      _liveSubtitleText = '';
      _liveStatus = context.l10n.preparingLiveSubtitles;
      _subtitles.clear();
      _subtitleKeys.clear();
      _currentSubtitleIndex = -1;
    });

    try {
      final response = await apiClient.sendAuthorizedMultipart(() async {
        final request = http.MultipartRequest(
          'POST',
          ApiConfig.endpoint('analyze_video/'),
        );
        request.fields.addAll({
          'mode': 'translate',
          'youtube_url': url,
          'source_language': _sourceLanguage,
          'target_language': _targetLanguage,
        });
        return request;
      });
      _resetLiveTranslationWatchdog(runId);
      if (response.statusCode != 200) {
        _stopLiveTranslationWatchdog();
        final body = await response.stream.bytesToString();
        final error = body.isEmpty ? null : jsonDecode(body);
        throw Exception(
          error is Map
              ? error['error'] ?? context.l10n.youtubeLiveTranslationFailed
              : context.l10n.youtubeLiveTranslationFailed,
        );
      }

      _liveTranslationSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (runId != _liveTranslationRunId || line.trim().isEmpty) return;
          _resetLiveTranslationWatchdog(runId);
          _handleLiveTranslationEvent(jsonDecode(line));
        },
        onError: (error) {
          if (!mounted || runId != _liveTranslationRunId) return;
          _stopLiveTranslationWatchdog();
          setState(() => _isTranslating = false);
          _showSnackBar(
            context.l10n.youtubeLiveTranslationFailedWithError(
              error.toString(),
            ),
            Colors.red,
          );
        },
        onDone: () {
          if (!mounted || runId != _liveTranslationRunId) return;
          _stopLiveTranslationWatchdog();
          setState(() {
            _isTranslating = false;
            _liveStatus = _subtitles.isEmpty
                ? context.l10n.noSpokenPhrasesDetected
                : context.l10n.liveSubtitlesReady;
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      _stopLiveTranslationWatchdog();
      setState(() => _isTranslating = false);
      _showSnackBar(
        context.l10n.youtubeLiveTranslationFailedWithError(e.toString()),
        Colors.red,
      );
    }
  }

  void _handleLiveTranslationEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'status') {
      setState(() => _liveStatus = event['message'] ?? '');
      return;
    }

    if (type == 'error') {
      _stopLiveTranslationWatchdog();
      setState(() {
        _isTranslating = false;
        _liveStatus = '';
      });
      _showSnackBar(
        event['error'] ?? context.l10n.liveTranslationFailed,
        Colors.red,
      );
      return;
    }

    if (type == 'complete') {
      _stopLiveTranslationWatchdog();
      setState(() {
        _isTranslating = false;
        _liveStatus = context.l10n.liveSubtitlesReady;
      });
      return;
    }

    if (type != 'segment') return;

    final original = (event['original'] ?? '').toString();
    final translated = (event['translated'] ?? '').toString();
    final start = (event['start'] as num?)?.toDouble() ?? 0;
    final rawEnd = (event['end'] as num?)?.toDouble() ?? start + 3;
    final end = rawEnd <= start ? start + 3 : rawEnd;

    setState(() {
      _subtitles.add({
        'startSeconds': start,
        'endSeconds': end,
        'start': _formatSubtitleTime(start),
        'end': _formatSubtitleTime(end),
        'original': original,
        'translated': translated,
      });
      _subtitleKeys.add(GlobalKey());
      _originalTranscript = [
        if (_originalTranscript.isNotEmpty) _originalTranscript,
        original,
      ].join(' ');
      _translatedText = [
        if (_translatedText.isNotEmpty) _translatedText,
        translated,
      ].join(' ');
      _liveStatus = context.l10n.translatedSpokenPhrases(_subtitles.length);
    });

    _syncLiveSubtitleToPlayback();
  }

  void _attachYouTubeController(OmniPlaybackController controller) {
    if (_youtubeController == controller) return;
    _youtubeController?.removeListener(_handleControllerNotification);
    _youtubeController = controller;
    _youtubeController?.addListener(_handleControllerNotification);
    _startPositionPolling();
  }

  void _syncLiveSubtitleToPlayback() {
    if (!mounted || _subtitles.isEmpty) return;

    final localController = _videoController;
    final seconds = localController != null
        ? localController.value.position.inMilliseconds / 1000.0
        : _currentEstimatedSeconds();
    if (localController != null) {
      _wasPlaying = localController.value.isPlaying;
    }
    // TEMPORARY — remove once sync is confirmed working.
    debugPrint(
        '[sync] pos=${seconds.toStringAsFixed(1)}s playing=$_wasPlaying subtitles=${_subtitles.length}');
    Map<String, dynamic>? activeSubtitle;
    for (final subtitle in _subtitles.reversed) {
      final start = (subtitle['startSeconds'] as num?)?.toDouble() ?? 0;
      final end = (subtitle['endSeconds'] as num?)?.toDouble() ?? start + 3;
      if (seconds >= start - 0.25 && seconds <= end + 0.75) {
        activeSubtitle = subtitle;
        break;
      }
    }

    final nextText = activeSubtitle == null
        ? ''
        : (activeSubtitle['translated'] ?? '').toString();
    final nextIndex =
        activeSubtitle == null ? -1 : _subtitles.indexOf(activeSubtitle);
    if (nextText == _liveSubtitleText && nextIndex == _currentSubtitleIndex) {
      return;
    }

    setState(() {
      _liveSubtitleText = nextText;
      _currentSubtitleIndex = nextIndex;
    });

    if (nextIndex >= 0 && nextIndex < _subtitleKeys.length) {
      final subtitleContext = _subtitleKeys[nextIndex].currentContext;
      if (subtitleContext != null) {
        Scrollable.ensureVisible(
          subtitleContext,
          duration: const Duration(milliseconds: 250),
          alignment: 0.35,
        );
      }
    }
  }

  void _seekToSubtitle(int index) {
    if (index < 0 || index >= _subtitles.length) return;
    final start = (_subtitles[index]['startSeconds'] as num?)?.toDouble() ?? 0;
    _youtubeController?.seekTo(Duration(milliseconds: (start * 1000).round()));
    // We initiated this seek ourselves, so we already know the target —
    // no need to wait for the player to report it back.
    _playbackBaselineSeconds = start;
    _playbackClock.reset();
    if (_wasPlaying) _playbackClock.start();
    _syncLiveSubtitleToPlayback();
  }

  String get _targetLanguageName => _languages
      .firstWhere((language) => language['code'] == _targetLanguage)['name']!;

  String _formatSubtitleTime(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$secs';
    }
    return '$minutes:$secs';
  }

  Future<void> _summarizeMedia(
      {File? file, Uint8List? bytes, String? filename}) async {
    if (file == null && bytes == null) {
      _showSnackBar(context.l10n.noMediaSelected, Colors.orange);
      return;
    }

    final apiClient = context.read<ApiClient>();
    setState(() => _isSummarizing = true);

    try {
      final formData = FormData.fromMap({
        'source_language': _sourceLanguage,
      });

      if (bytes != null) {
        formData.files.add(
          MapEntry(
            'video',
            MultipartFile.fromBytes(
              bytes,
              filename: filename ?? 'media.bin',
            ),
          ),
        );
      } else if (file != null) {
        formData.files.add(
          MapEntry(
            'video',
            await MultipartFile.fromFile(
              file.path,
              filename: filename ?? p.basename(file.path),
            ),
          ),
        );
      }

      final response = await apiClient.dio.post<Map<String, dynamic>>(
        'analyze_video/',
        data: formData,
      );
      final data = response.data;
      if (data == null) {
        throw Exception(context.l10n.emptyMediaSummaryResponse);
      }
      setState(() {
        _originalTranscript = '';
        _summaryText = data['summary_text']?.toString() ?? '';
        _summaryLanguageName = data['detected_language_name']?.toString() ?? '';
      });
      _showSnackBar(context.l10n.summaryComplete, Colors.orange);
    } catch (e) {
      _showSnackBar(
        context.l10n.mediaSummarizationFailed(e.toString()),
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isSummarizing = false);
      }
    }
  }

  Future<void> _summarizeYouTubeUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar(context.l10n.enterYoutubeUrl, Colors.orange);
      return;
    }

    setState(() => _isSummarizing = true);

    try {
      final response =
          await context.read<ApiClient>().dio.post<Map<String, dynamic>>(
                'analyze_video/',
                data: FormData.fromMap({
                  'mode': 'summarize',
                  'youtube_url': url,
                  'source_language': _sourceLanguage,
                }),
              );

      final data = response.data;
      if (data == null) {
        throw Exception(context.l10n.emptyYoutubeSummaryResponse);
      }
      setState(() {
        _originalTranscript = '';
        _summaryText = data['summary_text']?.toString() ?? '';
        _summaryLanguageName = data['detected_language_name']?.toString() ?? '';
        _isSummarizing = false;
      });

      _showSnackBar(context.l10n.summaryComplete, Colors.orange);
    } catch (e) {
      setState(() => _isSummarizing = false);
      _showSnackBar(
        context.l10n.youtubeSummarizationFailed(e.toString()),
        Colors.red,
      );
    }
  }

  Future<void> _runSummarize() async {
    if (_selectedMediaFile != null || _selectedMediaBytes != null) {
      await _summarizeMedia(
        file: _selectedMediaFile,
        bytes: _selectedMediaBytes,
        filename: _selectedMediaFileName,
      );
    } else if (_videoSource == 'youtube' &&
        _urlController.text.trim().isNotEmpty) {
      await _summarizeYouTubeUrl();
    } else if (_selectedMediaFile == null &&
        _selectedMediaBytes == null &&
        _videoSource != 'youtube') {
      _showSnackBar(context.l10n.selectOrRecordVideo, Colors.orange);
    } else {
      _showSnackBar(context.l10n.enterYoutubeUrlOrSelectVideo, Colors.orange);
    }
  }

  void _clearAll() {
    _liveTranslationRunId++;
    _liveTranslationSubscription?.cancel();
    _stopPositionPolling();
    _youtubeConfigCache = null;
    _youtubeConfigCacheUrl = null;
    _youtubeController?.removeListener(_handleControllerNotification);
    _playbackClock.stop();
    _playbackBaselineSeconds = 0;
    _wasPlaying = false;
    setState(() {
      _urlController.clear();
      _selectedMediaFile = null;
      _selectedMediaBytes = null;
      _selectedMediaFileName = null;
      _videoController?.dispose();
      _chewieController?.dispose();
      _youtubeController = null;
      _videoController = null;
      _chewieController = null;
      _originalTranscript = '';
      _translatedText = '';
      _summaryText = '';
      _summaryLanguageName = '';
      _liveSubtitleText = '';
      _liveStatus = '';
      _subtitles.clear();
      _subtitleKeys.clear();
      _currentSubtitleIndex = -1;
      _mediaType = null;
      _isPlayingSound = false;
    });
  }

  Future<void> _speakTranslatedText() async {
    if (_translatedText.isEmpty) {
      _showSnackBar(context.l10n.nothingToPlay, Colors.orange);
      return;
    }

    try {
      // Map simple language codes to TTS locales where possible
      final locale = _targetLanguage == 'en'
          ? 'en-US'
          : _targetLanguage == 'fr'
              ? 'fr-FR'
              : _targetLanguage == 'rw'
                  ? 'rw-RW'
                  : 'en-US';

      await _flutterTts.setLanguage(locale);
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);

      if (_isPlayingSound) {
        await _flutterTts.stop();
        setState(() => _isPlayingSound = false);
      } else {
        await _flutterTts.speak(_translatedText);
      }
    } catch (e) {
      _showSnackBar(context.l10n.unableToPlayAudio(e.toString()), Colors.red);
      setState(() => _isPlayingSound = false);
    }
  }

  void _applyTranslationPayload(Map<String, dynamic> payload) {
    final normalized = normalizeVideoTranslationPayload(payload);
    setState(() {
      _subtitles =
          (normalized['subtitles'] as List<Map<String, dynamic>>?)?.toList() ??
              <Map<String, dynamic>>[];
      _subtitleKeys
        ..clear()
        ..addAll(List.generate(_subtitles.length, (_) => GlobalKey()));
      _originalTranscript = normalized['originalTranscript'] as String;
      _translatedText = normalized['translatedText'] as String;
      _summaryText = normalized['summaryText'] as String;
      _summaryLanguageName = normalized['summaryLanguageName'] as String;
      _liveSubtitleText = normalized['liveSubtitleText'] as String;
      _currentSubtitleIndex = normalized['currentSubtitleIndex'] as int;
      _liveStatus = normalized['liveStatus'] as String;
      _mediaType = 'video';
    });
  }

  Widget _buildLiveSubtitleOverlay() {
    if (_liveSubtitleText.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: 22,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _showBothLanguages &&
                    _currentSubtitleIndex >= 0 &&
                    _currentSubtitleIndex < _subtitles.length
                ? '${_subtitles[_currentSubtitleIndex]['original']}\n$_liveSubtitleText'
                : _liveSubtitleText,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.videoTranslation),
          elevation: 0,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          leading: const AppMenuButton(),
          automaticallyImplyLeading: false,
          actions: const [AppBrandControls()],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hoverYouTube = true),
                      onExit: (_) => setState(() => _hoverYouTube = false),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.link, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.youtube,
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                        selected: _videoSource == 'youtube',
                        onSelected: (selected) {
                          if (selected) _setVideoSource('youtube');
                        },
                        selectedColor: Colors.white,
                        backgroundColor: _hoverYouTube
                            ? Colors.lightBlue.shade50
                            : Colors.white.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _hoverVideo = true),
                      onExit: (_) => setState(() => _hoverVideo = false),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.video_file, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.video,
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                        selected: _mediaType == 'video',
                        onSelected: (selected) {
                          if (selected) {
                            _setVideoSource('file');
                            _pickVideoFile();
                          }
                        },
                        selectedColor: Colors.white,
                        backgroundColor: _hoverVideo
                            ? Colors.lightBlue.shade50
                            : Colors.white.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _videoSource == 'youtube'
                            ? context.l10n.youtubeUrl
                            : context.l10n.videoFile,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_videoSource == 'youtube')
                        TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'https://youtube.com/watch?v=...',
                            prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      else if (_selectedMediaFile == null &&
                          _selectedMediaBytes == null)
                        InkWell(
                          onTap: _showVideoSourcePicker,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.video_call,
                                    size: 48, color: Colors.blue),
                                const SizedBox(height: 8),
                                Text(
                                  context.l10n.tapToSelectOrRecordVideo,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.video_file,
                                color: Colors.green,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedMediaFileName ??
                                          p.basename(_selectedMediaFile!.path),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _selectedMediaFile != null
                                          ? '${(_selectedMediaFile!.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB'
                                          : '${(_selectedMediaBytes!.length / 1024 / 1024).toStringAsFixed(1)} MB',
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _clearAll,
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ||
                                  _isTranslating ||
                                  _isSummarizing
                              ? null
                              : () async {
                                  if (_selectedMediaFile != null ||
                                      _selectedMediaBytes != null) {
                                    await _uploadMedia(
                                        file: _selectedMediaFile,
                                        bytes: _selectedMediaBytes,
                                        filename: _selectedMediaFileName);
                                  } else if (_videoSource == 'youtube' &&
                                      _urlController.text.trim().isNotEmpty) {
                                    await _translateYouTubeUrl();
                                  } else if (_selectedMediaFile == null &&
                                      _selectedMediaBytes == null &&
                                      _videoSource != 'youtube') {
                                    _showSnackBar(
                                        context.l10n.selectOrRecordVideo,
                                        Colors.orange);
                                  } else {
                                    _showSnackBar(
                                        context
                                            .l10n.enterYoutubeUrlOrSelectVideo,
                                        Colors.orange);
                                  }
                                },
                          icon: _isTranslating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.translate),
                          label: Text(
                            _isTranslating
                                ? context.l10n.translating
                                : context.l10n.translate,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Source & Target selectors
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _sourceLanguage,
                              decoration: InputDecoration(
                                labelText: context.l10n.sourceLanguage,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'auto',
                                  child: Text(context.l10n.auto),
                                ),
                                ..._languages.map((l) => DropdownMenuItem(
                                    value: l['code'], child: Text(l['name']!))),
                              ],
                              onChanged: (v) =>
                                  setState(() => _sourceLanguage = v ?? 'auto'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _targetLanguage,
                              decoration: InputDecoration(
                                labelText: context.l10n.targetLanguage,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _languages
                                  .map((l) => DropdownMenuItem(
                                      value: l['code'],
                                      child: Text(l['name']!)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() => _targetLanguage = v ?? 'en');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_mediaType == 'video' && _chewieController != null)
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Chewie(
                            controller: _chewieController!,
                          ),
                        ),
                        _buildLiveSubtitleOverlay(),
                      ],
                    ),
                  ),
                ),
              if (_mediaType == 'youtube' && _urlController.text.isNotEmpty)
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: OmniVideoPlayer(
                            configuration:
                                _youtubeConfigFor(_urlController.text.trim()),
                            callbacks: VideoPlayerCallbacks(
                              onControllerCreated: (controller) {
                                _attachYouTubeController(controller);
                                controller.play();
                                // We just called play() ourselves, so we know
                                // playback is starting from 0 — set the clock
                                // directly rather than waiting for the
                                // controller to notify us of this.
                                _playbackBaselineSeconds = 0;
                                _wasPlaying = true;
                                _playbackClock
                                  ..reset()
                                  ..start();
                              },
                              // Fires when the user drags the player's own
                              // scrubber (as opposed to tapping a transcript
                              // row, which is handled in _seekToSubtitle).
                              // Rebaseline our clock to whatever they seeked to.
                              onSeekEnd: (position) {
                                final seconds =
                                    position.inMilliseconds / 1000.0;
                                _playbackBaselineSeconds = seconds;
                                _playbackClock.reset();
                                if (_wasPlaying) _playbackClock.start();
                                _syncLiveSubtitleToPlayback();
                              },
                            ),
                          ),
                        ),
                        _buildLiveSubtitleOverlay(),
                      ],
                    ),
                  ),
                ),
              if (_liveStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      if (_isTranslating)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.subtitles,
                            size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _liveStatus,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (_summaryText.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.summarize, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _summaryLanguageName.isNotEmpty
                                  ? context.l10n.summaryForLanguage(
                                      _summaryLanguageName,
                                    )
                                  : context.l10n.summary,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _summaryText,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              if (_subtitles.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.liveTranscript,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => setState(
                                  () =>
                                      _showBothLanguages = !_showBothLanguages,
                                ),
                                child: Text(
                                  _showBothLanguages
                                      ? context.l10n.targetLanguageOnly(
                                          _targetLanguageName,
                                        )
                                      : context.l10n.showBothLanguages,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_translatedText.isNotEmpty)
                                SizedBox(
                                  height: 44,
                                  child: OutlinedButton(
                                    onPressed: _speakTranslatedText,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side:
                                          const BorderSide(color: Colors.blue),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(_isPlayingSound
                                            ? Icons.stop
                                            : Icons.volume_up),
                                        const SizedBox(width: 6),
                                        Text(
                                          _isPlayingSound
                                              ? context.l10n.stop
                                              : context.l10n.listen,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.builder(
                          controller: _subtitleScrollController,
                          shrinkWrap: true,
                          itemCount: _subtitles.length,
                          itemBuilder: (context, index) {
                            final subtitle = _subtitles[index];
                            final isActive = index == _currentSubtitleIndex;
                            final isPast = _currentSubtitleIndex >= 0 &&
                                index < _currentSubtitleIndex;

                            return GestureDetector(
                              onTap: () => _seekToSubtitle(index),
                              child: Container(
                                key: _subtitleKeys[index],
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.blue.shade100
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.blue
                                        : Colors.grey.shade200,
                                    width: isActive ? 1.4 : 1,
                                  ),
                                ),
                                child: Opacity(
                                  opacity: isPast ? 0.55 : 1,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${subtitle['start']} - ${subtitle['end']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (_showBothLanguages)
                                        Text(
                                          subtitle['original'],
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      if (_showBothLanguages)
                                        const Divider(height: 16),
                                      Text(
                                        subtitle['translated'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.studyTools,
                      style:
                          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStudyToolCard(
                            icon: Icons.summarize,
                            label: context.l10n.summarize,
                            color: Colors.orange,
                            onTap:
                                _isLoading || _isTranslating || _isSummarizing
                                    ? null
                                    : _runSummarize,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStudyToolCard(
                            icon: Icons.note_add,
                            label: context.l10n.studyNotes,
                            color: Colors.purple,
                            onTap: () {
                              if (_translatedText.isNotEmpty) {
                                _showSnackBar(
                                  context.l10n.notesSaved,
                                  Colors.purple,
                                );
                              } else {
                                _showSnackBar(
                                  context.l10n.translateFirst,
                                  Colors.orange,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStudyToolCard(
                            icon: Icons.translate,
                            label: context.l10n.vocabulary,
                            color: Colors.teal,
                            onTap: () {
                              if (_translatedText.isNotEmpty) {
                                _showSnackBar(
                                  context.l10n.keyVocabularyExtracted,
                                  Colors.teal,
                                );
                              } else {
                                _showSnackBar(
                                  context.l10n.translateFirst,
                                  Colors.orange,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStudyToolCard(
                            icon: Icons.quiz,
                            label: context.l10n.quiz,
                            color: Colors.brown,
                            onTap: () {
                              _showSnackBar(
                                context.l10n.quizGenerationComingSoon,
                                Colors.brown,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudyToolCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final effectiveColor = onTap == null ? Colors.grey : color;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: effectiveColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: effectiveColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoRecorderScreen extends StatefulWidget {
  const _VideoRecorderScreen();

  @override
  State<_VideoRecorderScreen> createState() => _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends State<_VideoRecorderScreen> {
  CameraController? _controller;
  Future<void>? _initializeCameraFuture;
  bool _isRecording = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCameraFuture = _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception(context.l10n.noCameraFound);
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      setState(() {
        _errorMessage = context.l10n.cameraOpenFailed(e.toString());
      });
    }
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      if (_isRecording) {
        final video = await controller.stopVideoRecording();
        if (!mounted) return;
        Navigator.of(context).pop(video);
        return;
      }

      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.l10n.videoRecordingFailed(e.toString());
        _isRecording = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.l10n.recordVideo),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: const [AppBrandControls()],
      ),
      body: FutureBuilder<void>(
        future: _initializeCameraFuture,
        builder: (context, snapshot) {
          if (_errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final controller = _controller;
          if (snapshot.connectionState != ConnectionState.done ||
              controller == null ||
              !controller.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize!.height,
                    height: controller.value.previewSize!.width,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(
                        _isRecording ? Icons.stop : Icons.fiber_manual_record),
                    label: Text(
                      _isRecording
                          ? context.l10n.stopRecording
                          : context.l10n.startRecording,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : Colors.white,
                      foregroundColor: _isRecording ? Colors.white : Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
