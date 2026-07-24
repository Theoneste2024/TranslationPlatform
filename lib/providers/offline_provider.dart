import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineProvider extends ChangeNotifier {
  bool _isOnline = true;
  final List<String> _downloadedPacks = [];
  int _activeDownloads = 0;
  final Connectivity _connectivity = Connectivity();

  OfflineProvider() {
    _initConnectivity();
  }

  bool get isOnline => _isOnline;
  List<String> get downloadedPacks => _downloadedPacks;
  int get activeDownloads => _activeDownloads;

  void _initConnectivity() {
    _connectivity.onConnectivityChanged.listen((results) {
      _isOnline = !results.contains(ConnectivityResult.none);
      notifyListeners();
    });
  }

  bool isPackDownloaded(String packId) {
    return _downloadedPacks.contains(packId);
  }

  void downloadPack(String packId) {
    _activeDownloads++;
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      _downloadedPacks.add(packId);
      _activeDownloads--;
      notifyListeners();
    });
  }

  void cancelDownload(String packId) {
    if (_activeDownloads > 0) {
      _activeDownloads--;
    }
    notifyListeners();
  }
}
