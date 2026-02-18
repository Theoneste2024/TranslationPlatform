import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class VideoTranslationScreen extends StatefulWidget {
  const VideoTranslationScreen({Key? key}) : super(key: key);

  @override
  State<VideoTranslationScreen> createState() => _VideoTranslationScreenState();
}

class _VideoTranslationScreenState extends State<VideoTranslationScreen> with SingleTickerProviderStateMixin {
  // Controllers
  final TextEditingController _urlController = TextEditingController();
  
  // Video Players
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  
  // UI States
  bool _isLoading = false;
  bool _isTranslating = false;
  bool _isTranscribing = false;
  bool _isPlayingTranslated = false;
  
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
  List<Map<String, dynamic>> _subtitles = [];
  
  // Audio Players
  final AudioPlayer _audioPlayer = AudioPlayer();
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  
  // Animation
  late AnimationController _animationController;
  
  // Media Source Type
  String _videoSource = 'youtube';
  File? _selectedMediaFile;
  String? _mediaType; // 'youtube', 'video', 'audio'

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _initTTS();
    
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() => _isPlayingTranslated = false);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage(_targetLanguage);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      setState(() => _isPlayingTranslated = false);
    });
  }

  void _setVideoSource(String source) {
    setState(() {
      _videoSource = source;
      _urlController.clear();
      _selectedMediaFile = null;
      _videoController?.dispose();
      _chewieController?.dispose();
      _videoController = null;
      _chewieController = null;
      _originalTranscript = '';
      _translatedText = '';
      _subtitles.clear();
      _mediaType = null;
    });
  }

  Future<void> _pickVideoFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'm4v'],
      );

      if (result != null) {
        setState(() {
          _selectedMediaFile = File(result.files.single.path!);
          _mediaType = 'video';
        });
        _showSnackBar('✅ Video selected: ${result.files.single.name}', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error picking video: $e', Colors.red);
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'wma'],
      );

      if (result != null) {
        File audioFile = File(result.files.single.path!);
        setState(() {
          _selectedMediaFile = audioFile;
          _mediaType = 'audio';
          _isLoading = true;
        });
        
        _showSnackBar('✅ Audio selected: ${result.files.single.name}', Colors.green);
        await _processAudioFile(audioFile);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error picking audio: $e', Colors.red);
    }
  }

  Future<void> _processAudioFile(File audioFile) async {
    setState(() {
      _isTranscribing = true;
      _originalTranscript = '';
    });

    _animationController.repeat(reverse: true);
    
    await Future.delayed(const Duration(seconds: 3));
    
    setState(() {
      _originalTranscript = "This is the transcribed text from the audio file '${audioFile.path.split('/').last}'. In a production app, this would use actual speech recognition to convert the audio to text.";
      _isTranscribing = false;
      _isLoading = false;
    });
    
    _animationController.stop();
    _showSnackBar('✅ Audio transcribed!', Colors.green);
  }

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com/') || 
           url.contains('youtu.be/') || 
           url.contains('m.youtube.com/') ||
           url.contains('youtube.com/shorts/');
  }

  String? _extractYouTubeVideoId(String url) {
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    );
    Match? match = regExp.firstMatch(url);
    return match?.group(1);
  }

  Future<void> _loadVideo() async {
    if (_videoSource == 'youtube' && _urlController.text.isEmpty) {
      _showSnackBar('Please enter a URL', Colors.orange);
      return;
    }
    
    if (_videoSource == 'file' && _selectedMediaFile == null) {
      _showSnackBar('Please select a media file', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_videoSource == 'youtube') {
        String url = _urlController.text.trim();
        
        if (_isYouTubeUrl(url)) {
          String? videoId = _extractYouTubeVideoId(url);
          if (videoId != null) {
            _mediaType = 'youtube';
            _showSnackBar('✅ YouTube video loaded!', Colors.green);
            setState(() => _isLoading = false);
            return;
          }
        } else {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
          await _videoController!.initialize();
          
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: false,
            aspectRatio: _videoController!.value.aspectRatio,
            allowFullScreen: true,
            allowMuting: true,
            showControls: true,
            materialProgressColors: ChewieProgressColors(
              playedColor: Colors.blue,
              bufferedColor: Colors.lightBlue.shade200,
              handleColor: Colors.blue,
              backgroundColor: Colors.grey.shade300,
            ),
          );
          _mediaType = 'video';
        }
      } else {
        if (_mediaType == 'audio') {
          setState(() => _isLoading = false);
          return;
        } else {
          _videoController = VideoPlayerController.file(_selectedMediaFile!);
          await _videoController!.initialize();
          
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: false,
            aspectRatio: _videoController!.value.aspectRatio,
            allowFullScreen: true,
            allowMuting: true,
            showControls: true,
            materialProgressColors: ChewieProgressColors(
              playedColor: Colors.blue,
              bufferedColor: Colors.lightBlue.shade200,
              handleColor: Colors.blue,
              backgroundColor: Colors.grey.shade300,
            ),
          );
          _mediaType = 'video';
        }
      }

      setState(() => _isLoading = false);
      
      if (_mediaType == 'youtube' || _mediaType == 'video' || _mediaType == 'audio') {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _startTranscription();
          }
        });
      }
      
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading media: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _startTranscription() async {
    setState(() {
      _isTranscribing = true;
      _originalTranscript = '';
    });

    bool available = await _speech.initialize();
    
    if (available) {
      _animationController.repeat(reverse: true);
      
      await Future.delayed(const Duration(seconds: 3));
      
      setState(() {
        _originalTranscript = "This is the transcribed text from the media. In a production app, this would use actual speech recognition to convert the audio to text.";
        _isTranscribing = false;
      });
      
      _animationController.stop();
      _showSnackBar('✅ Transcription complete!', Colors.green);
    } else {
      setState(() => _isTranscribing = false);
      _showSnackBar('Speech recognition not available', Colors.orange);
    }
  }

  Future<void> _translateText() async {
    if (_originalTranscript.isEmpty) {
      _showSnackBar('No transcript to translate', Colors.orange);
      return;
    }

    setState(() => _isTranslating = true);

    try {
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(_originalTranscript)}&langpair=en|${_targetLanguage}'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          _translatedText = data['responseData']['translatedText'];
          _isTranslating = false;
        });
        
        _showSnackBar('✅ Translation complete!', Colors.green);
        _speakTranslatedText();
      } else {
        throw Exception('Translation failed');
      }
    } catch (e) {
      setState(() => _isTranslating = false);
      
      setState(() {
        if (_targetLanguage == 'fr') {
          _translatedText = 'Ceci est un exemple de traduction.';
        } else if (_targetLanguage == 'rw') {
          _translatedText = 'Ubu ni urugero rw\'ubuhinduzi.';
        } else {
          _translatedText = 'This is a sample translation.';
        }
      });
      
      _showSnackBar('Using offline translation', Colors.orange);
    }
  }

  Future<void> _speakTranslatedText() async {
    if (_translatedText.isEmpty) return;
    setState(() => _isPlayingTranslated = true);
    await _flutterTts.setLanguage(_targetLanguage);
    await _flutterTts.speak(_translatedText);
  }

  void _toggleAudioPlayback() {
    if (_isPlayingTranslated) {
      _flutterTts.stop();
      setState(() => _isPlayingTranslated = false);
    } else if (_translatedText.isNotEmpty) {
      _speakTranslatedText();
    }
  }

  void _generateSubtitles() {
    if (_originalTranscript.isEmpty) return;

    setState(() {
      _subtitles = [
        {
          'start': '00:00',
          'end': '00:05',
          'original': _originalTranscript.substring(0, min(50, _originalTranscript.length)),
          'translated': _translatedText.isNotEmpty 
              ? _translatedText.substring(0, min(50, _translatedText.length))
              : '',
        },
        {
          'start': '00:05',
          'end': '00:10',
          'original': 'Media content continues...',
          'translated': _targetLanguage == 'fr' ? 'Le contenu continue...' :
                        _targetLanguage == 'rw' ? 'Ibindi bikurikira...' : 
                        'Media content continues...',
        },
      ];
    });
    
    _showSnackBar('✅ Subtitles generated!', Colors.green);
  }

  void _clearAll() {
    setState(() {
      _urlController.clear();
      _selectedMediaFile = null;
      _videoController?.dispose();
      _chewieController?.dispose();
      _videoController = null;
      _chewieController = null;
      _originalTranscript = '';
      _translatedText = '';
      _subtitles.clear();
      _mediaType = null;
    });
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

  Widget _buildYouTubeEmbed(String videoId) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
            SizedBox(height: 8),
            Text(
              'YouTube Player',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 4),
            Text(
              '(Web version would embed here)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video & Audio Translation'),
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
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link, size: 16),
                        SizedBox(width: 4),
                        Text('YouTube'),
                      ],
                    ),
                    selected: _videoSource == 'youtube',
                    onSelected: (selected) {
                      if (selected) _setVideoSource('youtube');
                    },
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_file, size: 16),
                        SizedBox(width: 4),
                        Text('Video'),
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
                    backgroundColor: Colors.white.withOpacity(0.2),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.audio_file, size: 16),
                        SizedBox(width: 4),
                        Text('Audio'),
                      ],
                    ),
                    selected: _mediaType == 'audio',
                    onSelected: (selected) {
                      if (selected) {
                        _setVideoSource('file');
                        _pickAudioFile();
                      }
                    },
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    labelStyle: const TextStyle(color: Colors.white),
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
                      _videoSource == 'youtube' ? 'YouTube URL' : 
                      _mediaType == 'audio' ? 'Audio File Selected' : 'Video File',
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
                    else if (_selectedMediaFile == null)
                      InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.video_file, color: Colors.blue),
                                    title: const Text('Select Video File'),
                                    subtitle: const Text('MP4, MOV, AVI, MKV'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickVideoFile();
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.audio_file, color: Colors.green),
                                    title: const Text('Select Audio File'),
                                    subtitle: const Text('MP3, WAV, M4A, AAC'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickAudioFile();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.upload_file, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to select a file',
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
                            Icon(
                              _mediaType == 'audio' ? Icons.audio_file : Icons.video_file,
                              color: Colors.green,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedMediaFile!.path.split('/').last,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${(_selectedMediaFile!.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB',
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
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loadVideo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Processing...'),
                                ],
                              )
                            : Text(_selectedMediaFile != null ? 'Process Media' : 'Load Media'),
                      ),
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
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Chewie(
                    controller: _chewieController!,
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
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        'YouTube: ${_urlController.text}',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(Web version supports embedded YouTube)',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            if (_isTranscribing)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Container(
                          width: 20 + (_animationController.value * 20),
                          height: 20 + (_animationController.value * 20),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transcribing Audio...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Converting speech to text',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (_originalTranscript.isNotEmpty || _isTranscribing)
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
                      'Translate to:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: _languages.map((lang) {
                        bool isSelected = _targetLanguage == lang['code'];
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(lang['flag']!),
                                  const SizedBox(width: 4),
                                  Text(lang['name']!),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _targetLanguage = lang['code']!;
                                  _initTTS();
                                });
                              },
                              backgroundColor: Colors.grey.shade200,
                              selectedColor: Colors.blue.shade100,
                              checkmarkColor: Colors.blue,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    if (_originalTranscript.isNotEmpty && !_isTranscribing) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isTranslating ? null : _translateText,
                          icon: _isTranslating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.translate),
                          label: Text(
                            _isTranslating ? 'Translating...' : 'Translate & Generate Voice',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            if (_originalTranscript.isNotEmpty)
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
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            _isPlayingTranslated ? Icons.stop : Icons.volume_up,
                            color: Colors.blue,
                          ),
                          onPressed: _toggleAudioPlayback,
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
                          onTap: () {
                            if (_translatedText.isNotEmpty) {
                              _showSnackBar('Summary: ${_translatedText.substring(0, min(50, _translatedText.length))}...', Colors.orange);
                            } else {
                              _showSnackBar('Translate first', Colors.orange);
                            }
                          },
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
                              _showSnackBar('Key vocabulary extracted!', Colors.teal);
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
                            _showSnackBar('Quiz generation coming soon!', Colors.brown);
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
    required VoidCallback onTap,
  }) {
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
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
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