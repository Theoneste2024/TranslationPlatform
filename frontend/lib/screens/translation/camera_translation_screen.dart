// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

import '../../l10n/app_localizations_extensions.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dotted_border/dotted_border.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/app_sidebar.dart';
import '../../widgets/app_header.dart';

class CameraTranslationScreen extends StatefulWidget {
  const CameraTranslationScreen({super.key});

  @override
  State<CameraTranslationScreen> createState() =>
      _CameraTranslationScreenState();
}

class _CameraTranslationScreenState extends State<CameraTranslationScreen> {
  File? _selectedImage;
  String _extractedText = '';
  String _translatedText = '';
  bool _isProcessing = false;

  CameraDevice _cameraDevice = CameraDevice.rear; // default rear camera

  late FlutterTts _flutterTts;

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _flutterTts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  // 🔄 Switch front/rear camera
  void _switchCamera() {
    setState(() {
      _cameraDevice = _cameraDevice == CameraDevice.rear
          ? CameraDevice.front
          : CameraDevice.rear;
    });
  }

  // ✅ Request camera permission
  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      status = await Permission.camera.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  // 📷 Take photo using camera
  Future<void> _takePhoto() async {
    bool hasPermission = await _requestCameraPermission();

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cameraPermissionRequired)),
      );
      return;
    }

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: _cameraDevice,
    );

    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
        _extractedText = '';
        _translatedText = '';
      });
      _processImage();
    }
  }

  // 📁 Upload photo from gallery
  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery);

    if (photo != null) {
      setState(() {
        _selectedImage = File(photo.path);
        _extractedText = '';
        _translatedText = '';
      });
      _processImage();
    }
  }

  // 🔍 Process image using Google ML Kit
  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final inputImage = InputImage.fromFile(_selectedImage!);
      final textRecognizer = GoogleMlKit.vision.textRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);

      String extracted = '';
      for (var block in recognizedText.blocks) {
        for (var line in block.lines) {
          extracted += '${line.text}\n';
        }
      }

      await textRecognizer.close();

      setState(() {
        _extractedText = extracted.isEmpty
            ? context.l10n.noTextFoundInImage
            : extracted;
        _isProcessing = false;
      });

      if (extracted.isNotEmpty) {
        _translateText();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.imageProcessingFailed(e.toString()))),
      );
    }
  }

  // 🌐 Translate text using MyMemory API
  Future<void> _translateText() async {
    if (_extractedText.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final url = Uri.parse(
          'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(_extractedText)}&langpair=en|fr');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translated = data['responseData']['translatedText'] ?? '';

        setState(() {
          _translatedText = translated;
          _isProcessing = false;
        });

        if (translated.isNotEmpty) {
          _flutterTts.speak(translated);
        }
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.imageTranslationFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.cameraTranslation),
          leading: const AppMenuButton(),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: _switchCamera, // switch front/rear
            ),
            const AppBrandControls(),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _selectedImage != null
                  ? Container(
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : DottedBorder(
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(12),
                      dashPattern: const [6, 3],
                      color: Colors.grey,
                      strokeWidth: 1.5,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt, size: 60),
                            const SizedBox(height: 10),
                            Text(context.l10n.takeOrUploadImage),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera),
                label: Text(
                  _cameraDevice == CameraDevice.rear
                      ? context.l10n.takeRearPhoto
                      : context.l10n.takeFrontPhoto,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _uploadPhoto,
                icon: const Icon(Icons.photo),
                label: Text(context.l10n.uploadPhoto),
              ),
              const SizedBox(height: 20),
              if (_isProcessing) const CircularProgressIndicator(),
              if (_extractedText.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_extractedText),
                  ),
                ),
              if (_translatedText.isNotEmpty)
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_translatedText),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
