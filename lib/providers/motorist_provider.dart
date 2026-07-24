import 'package:flutter/foundation.dart';

class MotoristProvider extends ChangeNotifier {
  bool _isNavigating = false;
  String? _currentDestination;
  bool _isListening = false;

  bool get isNavigating => _isNavigating;
  String? get currentDestination => _currentDestination;
  bool get isListening => _isListening;

  void startNavigation(String destination) {
    _isNavigating = true;
    _currentDestination = destination;
    notifyListeners();
  }

  void stopNavigation() {
    _isNavigating = false;
    _currentDestination = null;
    notifyListeners();
  }

  void setListening(bool value) {
    _isListening = value;
    notifyListeners();
  }
}
