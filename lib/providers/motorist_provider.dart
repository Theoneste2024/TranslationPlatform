import 'package:flutter_riverpod/flutter_riverpod.dart';

class MotoristState {
  final bool isNavigating;
  final String? currentDestination;
  final bool isListening;

  MotoristState({required this.isNavigating, required this.currentDestination, required this.isListening});

  MotoristState copyWith({bool? isNavigating, String? currentDestination, bool? isListening}) {
    return MotoristState(
      isNavigating: isNavigating ?? this.isNavigating,
      currentDestination: currentDestination ?? this.currentDestination,
      isListening: isListening ?? this.isListening,
    );
  }
}

class MotoristNotifier extends StateNotifier<MotoristState> {
  MotoristNotifier() : super(MotoristState(isNavigating: false, currentDestination: null, isListening: false));

  void startNavigation(String destination) {
    state = state.copyWith(isNavigating: true, currentDestination: destination);
  }

  void stopNavigation() {
    state = state.copyWith(isNavigating: false, currentDestination: null);
  }

  void setListening(bool value) {
    state = state.copyWith(isListening: value);
  }
}

final motoristProvider = StateNotifierProvider<MotoristNotifier, MotoristState>((ref) => MotoristNotifier());
