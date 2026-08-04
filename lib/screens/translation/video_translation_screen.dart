import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:omni_video_player/omni_video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_constants.dart';
import 'package:path/path.dart' as p;

class VideoTranslationScreen extends StatefulWidget {
  const VideoTranslationScreen({super.key});

  @override
  State<VideoTranslationScreen> createState() => _VideoTranslationScreenState();
}

class _VideoTranslationScreenState extends State<VideoTranslationScreen> {
  // Controllers
  final TextEditingController _urlController = TextEditingController();
  late FlutterTts _flutterTts;

  // Video Players
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  OmniPlaybackController? _youtubeController;
  StreamSubscription<String>? _liveTranslationSubscription;
  Timer? _liveTranslationWatchdog;

  // UI States
  final bool _isLoading = false;
  bool _isTranslating = false;
  bool _isSummarizing = false;
  bool _isAudioEnabled = false;
  bool _isSpeaking = false;
  String? _lastSpokenSubtitleId;
  static const Duration _liveTranslationInitialTimeout = Duration(seconds: 25);

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
  static const Duration _liveTranslationIdleTimeout = Duration(minutes: 3);

  // Media Source Type
  String _videoSource = 'youtube';
  File? _selectedMediaFile;
  Uint8List? _selectedMediaBytes;
  String? _selectedMediaFileName;
  String? _mediaType; // 'youtube', 'video'
  // Hover states for chips
  bool _hoverYouTube = false;
  bool _hoverVideo = false;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _flutterTts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _lastSpokenSubtitleId = null;
      });
      _restorePlaybackVolume();
    });
    _flutterTts.setErrorHandler((message) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _lastSpokenSubtitleId = null;
      });
      _restorePlaybackVolume();
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _urlController.dispose();
    _liveTranslationSubscription?.cancel();
    _liveTranslationWatchdog?.cancel();
    _youtubeController?.removeListener(_syncLiveSubtitleToPlayback);
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _resetLiveTranslationWatchdog(int runId, {Duration? timeout}) {
    _liveTranslationWatchdog?.cancel();
    _liveTranslationWatchdog = Timer(timeout ?? _liveTranslationIdleTimeout, () {
      if (!mounted || runId != _liveTranslationRunId || !_isTranslating) return;
      _liveTranslationSubscription?.cancel();
      setState(() {
        _isTranslating = false;
        _liveStatus =
            'Live translation timed out. Please try again with a shorter video.';
      });
      _showSnackBar(
        'Live translation timed out. Please try again with a shorter video.',
        Colors.red,
      );
    });
  }

  void _stopLiveTranslationWatchdog() {
    _liveTranslationWatchdog?.cancel();
    _liveTranslationWatchdog = null;
  }

  void _setVideoSource(String source) {
    setState(() {
      _videoSource = source;
      _urlController.clear();
      _selectedMediaFile = null;
      _selectedMediaBytes = null;
      _selectedMediaFileName = null;
      _videoController?.dispose();
      _chewieController?.dispose();
      _liveTranslationSubscription?.cancel();
      _youtubeController?.removeListener(_syncLiveSubtitleToPlayback);
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
      _mediaType = null;
      _isAudioEnabled = false;
      _isSpeaking = false;
      _lastSpokenSubtitleId = null;
    });
    _flutterTts.stop();
    _restorePlaybackVolume();
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
          'Camera or microphone access is permanently denied. Please enable it in app settings.',
          Colors.orange);
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
        'Camera and microphone permissions are required to record video.',
        Colors.orange);
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
                const Text(
                  'Choose how to provide your video',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.blue),
                  title: const Text('Record video'),
                  subtitle:
                      const Text('Use your camera to capture a new video'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _recordVideo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.green),
                  title: const Text('Upload video from local storage'),
                  subtitle: const Text('Pick a video file from your device'),
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
        _showSnackBar('No video file was selected.', Colors.orange);
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
      _showSnackBar('✅ Video selected: ${picked.name}', Colors.green);
    } catch (e) {
      _showSnackBar('Unable to pick the video file: $e', Colors.red);
    }
  }

  Future<void> _recordVideo() async {
    try {
      final hasPermission = await _requestVideoRecordingPermissions();
      if (!hasPermission) {
        return;
      }

      if (!mounted) return;
      final XFile? video = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(
          builder: (_) => const _VideoRecorderScreen(),
        ),
      );
      if (!mounted) return;
      if (video == null) {
        _showSnackBar('No video was recorded.', Colors.orange);
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

      _showSnackBar('✅ Video recorded: ${video.name}', Colors.green);
    } catch (e) {
      _showSnackBar('Unable to record the video: $e', Colors.red);
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

  Future<void> _uploadMedia(
      {File? file, Uint8List? bytes, String? filename}) async {
    if (file == null && bytes == null) {
      _showSnackBar('No media selected', Colors.orange);
      return;
    }

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
      _liveStatus = 'Preparing streamed subtitles...';
      _subtitles.clear();
    });
    _resetLiveTranslationWatchdog(runId, timeout: _liveTranslationInitialTimeout);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConstants.videoTranslateStream),
      );
      request.fields['source_language'] = _sourceLanguage;
      request.fields['target_language'] = _targetLanguage;

      if (bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            bytes,
            filename: filename ?? 'media.bin',
          ),
        );
      } else if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            file.path,
            filename: filename ?? p.basename(file.path),
          ),
        );
      }

      final response = await request.send();
      _resetLiveTranslationWatchdog(runId);
      if (response.statusCode != 200) {
        _stopLiveTranslationWatchdog();
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        throw Exception(data['error'] ?? 'Media upload failed');
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
          _showSnackBar('Media upload failed: $error', Colors.red);
        },
        onDone: () {
          if (!mounted || runId != _liveTranslationRunId) return;
          _stopLiveTranslationWatchdog();
          setState(() {
            _isTranslating = false;
            _liveStatus = _subtitles.isEmpty
                ? 'No spoken phrases were detected.'
                : 'Streamed subtitles ready.';
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      _stopLiveTranslationWatchdog();
      setState(() => _isTranslating = false);
      _showSnackBar('Media upload failed: $e', Colors.red);
    }
  }

  // Translate a YouTube URL by streaming timestamped subtitle segments from the backend.
  Future<void> _translateYouTubeUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter a YouTube URL', Colors.orange);
      return;
    }

    final runId = ++_liveTranslationRunId;
    await _liveTranslationSubscription?.cancel();
    _resetLiveTranslationWatchdog(runId, timeout: _liveTranslationInitialTimeout);
    setState(() {
      _isTranslating = true;
      _mediaType = 'youtube';
      _originalTranscript = '';
      _translatedText = '';
      _summaryText = '';
      _summaryLanguageName = '';
      _liveSubtitleText = '';
      _liveStatus = 'Preparing live translated subtitles...';
      _subtitles.clear();
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConstants.videoTranslateStream),
      );
      request.fields['youtube_url'] = url;
      request.fields['source_language'] = _sourceLanguage;
      request.fields['target_language'] = _targetLanguage;

      final response = await request.send();
      _resetLiveTranslationWatchdog(runId);
      if (response.statusCode != 200) {
        _stopLiveTranslationWatchdog();
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        throw Exception(data['error'] ?? 'YouTube live translation failed');
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
          _showSnackBar('YouTube live translation failed: $error', Colors.red);
        },
        onDone: () {
          if (!mounted || runId != _liveTranslationRunId) return;
          _stopLiveTranslationWatchdog();
          setState(() {
            _isTranslating = false;
            _liveStatus = _subtitles.isEmpty
                ? 'No spoken phrases were detected.'
                : 'Live subtitles ready.';
          });
        },
        cancelOnError: true,
      );
    } catch (e) {
      _stopLiveTranslationWatchdog();
      setState(() => _isTranslating = false);
      _showSnackBar('YouTube live translation failed: $e', Colors.red);
    }
  }

  void _handleLiveTranslationEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'status') {
      _resetLiveTranslationWatchdog(_liveTranslationRunId, timeout: _liveTranslationIdleTimeout);
      setState(() => _liveStatus = event['message'] ?? '');
      return;
    }

    if (type == 'error') {
      _stopLiveTranslationWatchdog();
      setState(() {
        _isTranslating = false;
        _liveStatus = '';
      });
      _showSnackBar(event['error'] ?? 'Live translation failed', Colors.red);
      return;
    }

    if (type == 'complete') {
      _stopLiveTranslationWatchdog();
      setState(() {
        _isTranslating = false;
        _liveStatus = 'Live subtitles ready.';
      });
      return;
    }

    if (type != 'segment') return;

    final original = (event['original'] ?? '').toString();
    final translated = (event['translated'] ?? '').toString();
    final start = (event['start'] as num?)?.toDouble() ?? 0;
    final rawEnd = (event['end'] as num?)?.toDouble() ?? start + 3;
    final end = rawEnd <= start ? start + 3 : rawEnd;

    final recentSubtitles = _subtitles.length > 6
        ? _subtitles.sublist(_subtitles.length - 6)
        : _subtitles;
    final isDuplicate = recentSubtitles.any((subtitle) {
      final existingStart = (subtitle['startSeconds'] as num?)?.toDouble() ?? 0;
      final existingEnd = (subtitle['endSeconds'] as num?)?.toDouble() ?? existingStart + 3;
      return (start >= existingStart - 0.75 && start <= existingEnd + 0.75) ||
          (end >= existingStart - 0.75 && end <= existingEnd + 0.75);
    });

    _resetLiveTranslationWatchdog(_liveTranslationRunId, timeout: _liveTranslationIdleTimeout);

    if (isDuplicate) return;

    setState(() {
      _subtitles.add({
        'startSeconds': start,
        'endSeconds': end,
        'start': _formatSubtitleTime(start),
        'end': _formatSubtitleTime(end),
        'original': original,
        'translated': translated,
      });
      _originalTranscript = [
        if (_originalTranscript.isNotEmpty) _originalTranscript,
        original,
      ].join(' ');
      _translatedText = [
        if (_translatedText.isNotEmpty) _translatedText,
        translated,
      ].join(' ');
      _liveStatus =
          'Translated ${_subtitles.length} spoken phrase${_subtitles.length == 1 ? '' : 's'}...';
    });

    _syncLiveSubtitleToPlayback();
  }

  void _attachYouTubeController(OmniPlaybackController controller) {
    if (_youtubeController == controller) return;
    _youtubeController?.removeListener(_syncLiveSubtitleToPlayback);
    _youtubeController = controller;
    _youtubeController?.addListener(_syncLiveSubtitleToPlayback);
    _syncLiveSubtitleToPlayback();
  }

  void _syncLiveSubtitleToPlayback() {
    if (!mounted || _subtitles.isEmpty) return;

    final position = _youtubeController?.currentPosition.inMilliseconds;
    if (position == null) return;

    final seconds = position / 1000.0;
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
    final subtitleId = activeSubtitle == null
        ? null
        : ((activeSubtitle['startSeconds'] as num?)?.toString() ?? '');
    final shouldSpeak = _isAudioEnabled &&
        activeSubtitle != null &&
        subtitleId != null &&
        subtitleId != _lastSpokenSubtitleId &&
        nextText.trim().isNotEmpty;

    if (nextText == _liveSubtitleText && !shouldSpeak) return;

    setState(() {
      _liveSubtitleText = nextText;
      if (shouldSpeak) {
        _lastSpokenSubtitleId = subtitleId;
      }
    });

    if (shouldSpeak) {
      unawaited(_speakTranslatedText(
        nextText,
        language: _targetLanguage,
        subtitleId: subtitleId,
      ));
    }
  }

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
      _showSnackBar('No media selected', Colors.orange);
      return;
    }

    setState(() => _isSummarizing = true);

    try {
      final request =
          http.MultipartRequest('POST', Uri.parse(AppConstants.videoSummarize));
      request.fields['source_language'] = _sourceLanguage;

      if (bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            bytes,
            filename: filename ?? 'media.bin',
          ),
        );
      } else if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            file.path,
            filename: filename ?? p.basename(file.path),
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _originalTranscript = '';
          _summaryText = data['summary_text'] ?? '';
          _summaryLanguageName = data['detected_language_name'] ?? '';
        });
        _showSnackBar('Summary complete!', Colors.orange);
      } else {
        throw Exception(data['error'] ?? 'Media summarization failed');
      }
    } catch (e) {
      _showSnackBar('Media summarization failed: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isSummarizing = false);
      }
    }
  }

  Future<void> _summarizeYouTubeUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter a YouTube URL', Colors.orange);
      return;
    }

    setState(() => _isSummarizing = true);

    try {
      final response = await http.post(
        Uri.parse(AppConstants.videoSummarize),
        body: {
          'youtube_url': url,
          'source_language': _sourceLanguage,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _originalTranscript = '';
          _summaryText = data['summary_text'] ?? '';
          _summaryLanguageName = data['detected_language_name'] ?? '';
          _isSummarizing = false;
        });

        _showSnackBar('Summary complete!', Colors.orange);
      } else {
        throw Exception(data['error'] ?? 'YouTube summarization failed');
      }
    } catch (e) {
      setState(() => _isSummarizing = false);
      _showSnackBar('YouTube summarization failed: $e', Colors.red);
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
      _showSnackBar(
          'Please select a video file or record a video first.', Colors.orange);
    } else {
      _showSnackBar(
          'Please enter a YouTube URL or select a video first.', Colors.orange);
    }
  }

  void _generateSubtitles() {
    if (_originalTranscript.isEmpty) return;

    setState(() {
      _subtitles = [
        {
          'start': '00:00',
          'end': '00:05',
          'original': _originalTranscript.substring(
              0, min(50, _originalTranscript.length)),
          'translated': _translatedText.isNotEmpty
              ? _translatedText.substring(0, min(50, _translatedText.length))
              : '',
        },
        {
          'start': '00:05',
          'end': '00:10',
          'original': 'Media content continues...',
          'translated': _targetLanguage == 'fr'
              ? 'Le contenu continue...'
              : _targetLanguage == 'rw'
                  ? 'Ibindi bikurikira...'
                  : 'Media content continues...',
        },
      ];
    });

    _showSnackBar('✅ Subtitles generated!', Colors.green);
  }

  void _clearAll() {
    _liveTranslationRunId++;
    _liveTranslationSubscription?.cancel();
    _youtubeController?.removeListener(_syncLiveSubtitleToPlayback);
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
      _mediaType = null;
      _isAudioEnabled = false;
      _isSpeaking = false;
      _lastSpokenSubtitleId = null;
    });
    _flutterTts.stop();
    _restorePlaybackVolume();
  }

  String _ttsLocaleFor(String language) {
    final normalized = (language).trim().toLowerCase();
    switch (normalized) {
      case 'en':
        return 'en-US';
      case 'fr':
        return 'fr-FR';
      case 'rw':
        return 'rw-RW';
      default:
        return normalized.isEmpty ? 'en-US' : normalized;
    }
  }

  Future<void> _speakTranslatedText(String text,
      {required String language, String? subtitleId}) async {
    if (!_isAudioEnabled || text.trim().isEmpty) return;

    if (subtitleId != null && mounted) {
      setState(() => _lastSpokenSubtitleId = subtitleId);
    }

    await _flutterTts.stop();
    _duckPlaybackVolume();
    await _flutterTts.setLanguage(_ttsLocaleFor(language));
    await _flutterTts.speak(text.trim());
  }

  Future<void> _stopTranslatedAudio() async {
    await _flutterTts.stop();
    _restorePlaybackVolume();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _lastSpokenSubtitleId = null;
      });
    }
  }

  void _duckPlaybackVolume() {
    if (_mediaType == 'video' && _chewieController != null) {
      unawaited(_chewieController!.videoPlayerController.setVolume(0.15));
    } else if (_youtubeController != null) {
      unawaited((_youtubeController as dynamic).setVolume(0.15));
    }
  }

  void _restorePlaybackVolume() {
    if (_mediaType == 'video' && _chewieController != null) {
      unawaited(_chewieController!.videoPlayerController.setVolume(1.0));
    } else if (_youtubeController != null) {
      unawaited((_youtubeController as dynamic).setVolume(1.0));
    }
  }

  Future<void> _toggleTranslatedAudio() async {
    final nextValue = !_isAudioEnabled;
    if (!mounted) return;

    setState(() => _isAudioEnabled = nextValue);

    if (!nextValue) {
      await _stopTranslatedAudio();
      return;
    }

    if (_translatedText.trim().isNotEmpty) {
      await _speakTranslatedText(_translatedText, language: _targetLanguage);
      return;
    }

    if (_videoSource == 'youtube' && _subtitles.isNotEmpty) {
      _syncLiveSubtitleToPlayback();
    }
  }

  Widget _buildDubToggleButton() {
    final isOn = _isAudioEnabled;
    return Tooltip(
      message: isOn ? 'Turn off translated audio' : 'Turn on translated audio',
      child: InkWell(
        onTap: _toggleTranslatedAudio,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isOn
                ? Colors.blue.withValues(alpha: 0.9)
                : Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(
            isOn
                ? (_isSpeaking ? Icons.record_voice_over : Icons.volume_up)
                : Icons.volume_off,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Translation'),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearAll,
            tooltip: 'Clear All',
          ),
        ],
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
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.link, size: 16),
                          SizedBox(width: 4),
                          Text('YouTube', style: TextStyle(color: Colors.blue)),
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
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_file, size: 16),
                          SizedBox(width: 4),
                          Text('Video', style: TextStyle(color: Colors.blue)),
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
                      _videoSource == 'youtube' ? 'YouTube URL' : 'Video File',
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
                                'Tap to select a video file or record video',
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
                                    style: const TextStyle(color: Colors.grey),
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
                        onPressed:
                            _isLoading || _isTranslating || _isSummarizing
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
                                          'Please select a video file or record a video first.',
                                          Colors.orange);
                                    } else {
                                      _showSnackBar(
                                          'Please enter a YouTube URL or select a video first.',
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
                            _isTranslating ? 'Translating...' : 'Translate'),
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
                              labelText: 'Source language',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: 'auto', child: Text('Auto')),
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
                              labelText: 'Target language',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            items: _languages
                                .map((l) => DropdownMenuItem(
                                    value: l['code'], child: Text(l['name']!)))
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
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _buildDubToggleButton(),
                      ),
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
                          configuration: VideoPlayerConfiguration(
                            videoSourceConfiguration:
                                VideoSourceConfiguration.youtube(
                              videoUrl: Uri.parse(_urlController.text.trim()),
                            ),
                          ),
                          callbacks: VideoPlayerCallbacks(
                            onControllerCreated: (controller) {
                              _attachYouTubeController(controller);
                              controller.play();
                            },
                            onSeekEnd: (_) => _syncLiveSubtitleToPlayback(),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _buildDubToggleButton(),
                      ),
                      if (_liveSubtitleText.isNotEmpty)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 22,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _liveSubtitleText,
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
                        ),
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
                      const Icon(Icons.subtitles, size: 16, color: Colors.blue),
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
            if (_originalTranscript.isNotEmpty && _summaryText.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Original Transcript:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_originalTranscript),
                  ],
                ),
              ),
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
                                ? 'Summary ($_summaryLanguageName):'
                                : 'Summary:',
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
            if (_translatedText.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.translate, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Translated (${_languages.firstWhere((l) => l['code'] == _targetLanguage)['name']}):',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _translatedText,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _generateSubtitles,
                            icon: const Icon(Icons.subtitles),
                            label: const Text('Generate Subtitles'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                            ),
                          ),
                        ),
                      ],
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
                    const Text(
                      'Generated Subtitles:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._subtitles.map((subtitle) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${subtitle['start']} - ${subtitle['end']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle['original'],
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (subtitle['translated'].isNotEmpty) ...[
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
                            ],
                          ),
                        )),
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
                  const Text(
                    'Study Tools',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStudyToolCard(
                          icon: Icons.summarize,
                          label: 'Summarize',
                          color: Colors.orange,
                          onTap: _isLoading || _isTranslating || _isSummarizing
                              ? null
                              : _runSummarize,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStudyToolCard(
                          icon: Icons.note_add,
                          label: 'Study Notes',
                          color: Colors.purple,
                          onTap: () {
                            if (_translatedText.isNotEmpty) {
                              _showSnackBar('Notes saved!', Colors.purple);
                            } else {
                              _showSnackBar('Translate first', Colors.orange);
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
                          label: 'Vocabulary',
                          color: Colors.teal,
                          onTap: () {
                            if (_translatedText.isNotEmpty) {
                              _showSnackBar(
                                  'Key vocabulary extracted!', Colors.teal);
                            } else {
                              _showSnackBar('Translate first', Colors.orange);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStudyToolCard(
                          icon: Icons.quiz,
                          label: 'Quiz',
                          color: Colors.brown,
                          onTap: () {
                            _showSnackBar(
                                'Quiz generation coming soon!', Colors.brown);
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
        throw Exception('No camera was found on this device.');
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
        _errorMessage = 'Unable to open camera: $e';
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
        _errorMessage = 'Recording failed: $e';
        _isRecording = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Record Video'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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
                        _isRecording ? 'Stop Recording' : 'Start Recording'),
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
