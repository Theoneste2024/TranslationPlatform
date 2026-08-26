import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OfflineState {
  final bool isOnline;
  final List<String> downloadedPacks;
  final int activeDownloads;

  OfflineState({
    required this.isOnline,
    required this.downloadedPacks,
    required this.activeDownloads,
  });

  OfflineState copyWith({
    bool? isOnline,
    List<String>? downloadedPacks,
    int? activeDownloads,
  }) {
    return OfflineState(
      isOnline: isOnline ?? this.isOnline,
      downloadedPacks: downloadedPacks ?? List.from(this.downloadedPacks),
      activeDownloads: activeDownloads ?? this.activeDownloads,
    );
  }
}

class OfflineNotifier extends StateNotifier<OfflineState> {
  final Connectivity _connectivity = Connectivity();

  OfflineNotifier()
      : super(OfflineState(isOnline: true, downloadedPacks: [], activeDownloads: 0)) {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivity.onConnectivityChanged.listen((results) {
      final online = !results.toString().contains('none');
      state = state.copyWith(isOnline: online);
    });
  }

  bool isPackDownloaded(String packId) {
    return state.downloadedPacks.contains(packId);
  }

  void downloadPack(String packId) {
    state = state.copyWith(activeDownloads: state.activeDownloads + 1);
    Future.delayed(const Duration(seconds: 2), () {
      final updated = List<String>.from(state.downloadedPacks)..add(packId);
      state = state.copyWith(downloadedPacks: updated, activeDownloads: state.activeDownloads - 1);
    });
  }

  void cancelDownload(String packId) {
    if (state.activeDownloads > 0) {
      state = state.copyWith(activeDownloads: state.activeDownloads - 1);
    }
  }
}

final offlineProvider = StateNotifierProvider<OfflineNotifier, OfflineState>((ref) => OfflineNotifier());
