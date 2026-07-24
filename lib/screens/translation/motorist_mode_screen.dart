import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart'; // ✅ FREE OSM - NO API KEY
import 'package:latlong2/latlong.dart'; // ✅ FREE coordinates
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class MotoristModeScreen extends StatefulWidget {
  const MotoristModeScreen({super.key});

  @override
  State<MotoristModeScreen> createState() => _MotoristModeScreenState();
}

class _MotoristModeScreenState extends State<MotoristModeScreen>
    with WidgetsBindingObserver {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isNavigating = false;

  // ✅ FREE OpenStreetMap controller
  final MapController _mapController = MapController();

  // ✅ Use LatLng from latlong2 package
  LatLng? _currentPosition;

  // ✅ Use flutter_map Marker (not Google Maps Marker)
  final List<Marker> _markers = [];

  // Voice commands for motorists
  final List<String> _voiceCommands = [
    'translate',
    'navigate to',
    'where is',
    'how much',
    'stop here',
    'call passenger',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initMotoristMode();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speech.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Keep audio service running in background
    }
  }

  Future<void> _initMotoristMode() async {
    await _initTTS();
    await _getCurrentLocation();
    _startContinuousListening();
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage('rw');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _addCurrentLocationMarker();
      });
      _mapController.move(_currentPosition!, 15.0);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  // ✅ Add current location marker
  void _addCurrentLocationMarker() {
    _markers.clear();
    _markers.add(
      Marker(
        point: _currentPosition!,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.navigation, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _startContinuousListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _startContinuousListening();
            }
          });
        }
      },
      onError: (error) => debugPrint('Speech error: $error'),
    );

    if (available) {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) => _processVoiceCommand(result.recognizedWords),
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(seconds: 3),
        localeId: 'rw_RW',
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
        ),
      );
    }
  }

  void _processVoiceCommand(String command) {
    command = command.toLowerCase();

    _flutterTts.speak('Received command');

    if (command.contains('translate')) {
      _handleTranslationCommand(command);
    } else if (command.contains('navigate to') ||
        command.contains('where is')) {
      _handleNavigationCommand(command);
    } else if (command.contains('how much')) {
      _handleFareCalculation();
    } else if (command.contains('stop here')) {
      _handleStopRequest();
    } else if (command.contains('call passenger')) {
      _handleCallPassenger();
    }
  }

  void _handleTranslationCommand(String command) {
    String textToTranslate = command.replaceAll('translate', '').trim();

    if (textToTranslate.isNotEmpty) {
      _flutterTts.speak('Ibyo muvuga bivuze: $textToTranslate');
      _flutterTts.setLanguage('en');
      _flutterTts.speak('You said: $textToTranslate');
      _flutterTts.setLanguage('rw');
    }
  }

  void _handleNavigationCommand(String command) {
    String destination =
        command.replaceAll('navigate to', '').replaceAll('where is', '').trim();

    _flutterTts.speak('Navigating to $destination');
    setState(() {
      _isNavigating = true;
    });

    _addDestinationMarker(destination);
  }

  void _handleFareCalculation() {
    if (_currentPosition != null) {
      _flutterTts.speak('The fare will be approximately 2000 Rwandan francs');
    }
  }

  void _handleStopRequest() {
    _flutterTts.speak('Stopping at next safe location');
    setState(() {
      _isNavigating = false;
    });
  }

  void _handleCallPassenger() {
    _flutterTts.speak('Calling passenger');
  }

  void _addDestinationMarker(String destination) {
    if (_currentPosition != null) {
      setState(() {
        _markers.add(
          Marker(
            point: LatLng(
              _currentPosition!.latitude + 0.01,
              _currentPosition!.longitude + 0.01,
            ),
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child:
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ✅ FREE OpenStreetMap - NO API KEY REQUIRED
          if (_currentPosition != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition!,
                initialZoom: 15.0,
                maxZoom: 19.0,
                minZoom: 6.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.translation.platform',
                ),
                MarkerLayer(markers: _markers),
              ],
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Motorist Mode Overlay
          SafeArea(
            child: Column(
              children: [
                // Status Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isListening ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_off,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Motorist Mode Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _isListening
                                  ? 'Listening for commands...'
                                  : 'Tap to activate',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_voice,
                            color: Colors.white),
                        onPressed: _showVoiceCommands,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Quick Action Buttons
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickActionButton(
                            icon: Icons.translate,
                            label: 'Translate',
                            onTap: () {
                              _flutterTts
                                  .speak('Say what you want to translate');
                            },
                          ),
                          _buildQuickActionButton(
                            icon: Icons.map,
                            label: 'Navigate',
                            onTap: () {
                              _flutterTts.speak('Where do you want to go?');
                            },
                          ),
                          _buildQuickActionButton(
                            icon: Icons.attach_money,
                            label: 'Fare',
                            onTap: _handleFareCalculation,
                          ),
                          _buildQuickActionButton(
                            icon: Icons.phone,
                            label: 'Call',
                            onTap: _handleCallPassenger,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isNavigating
                                  ? Icons.navigation
                                  : Icons.location_on,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isNavigating
                                        ? 'Currently navigating'
                                        : 'Ready for passengers',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _isNavigating
                                        ? 'Follow the route'
                                        : 'Tap to start navigation',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showVoiceCommands() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voice Commands',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ..._voiceCommands.map((command) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        '"$command"',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
