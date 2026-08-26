import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserModel {
  final String name;
  final String email;
  final String photoURL;

  UserModel({
    required this.name,
    required this.email,
    required this.photoURL,
  });
}

class AuthState {
  final bool isAuthenticated;
  final UserModel? user;

  AuthState({required this.isAuthenticated, required this.user});

  AuthState copyWith({bool? isAuthenticated, UserModel? user}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState(isAuthenticated: false, user: null));

  void login({required String email, required String password}) {
    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();

    if (normalizedEmail.isEmpty || normalizedPassword.isEmpty) {
      return;
    }

    state = state.copyWith(
      isAuthenticated: true,
      user: UserModel(
        name: 'Demo User',
        email: normalizedEmail,
        photoURL: '',
      ),
    );
  }

  void register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) {
    final normalizedName = fullName.trim();
    final normalizedUsername = username.trim();
    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();

    if (normalizedName.isEmpty || normalizedUsername.isEmpty || normalizedEmail.isEmpty || normalizedPassword.isEmpty) {
      return;
    }

    state = state.copyWith(
      isAuthenticated: true,
      user: UserModel(
        name: normalizedName.isEmpty ? 'New User' : normalizedName,
        email: normalizedEmail.isEmpty ? 'user@example.com' : normalizedEmail,
        photoURL: '',
      ),
    );
  }

  void logout() {
    state = state.copyWith(isAuthenticated: false, user: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
