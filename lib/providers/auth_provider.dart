import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  UserModel? _user;

  bool get isAuthenticated => _isAuthenticated;
  UserModel? get user => _user;

  void login() {
    _isAuthenticated = true;
    _user = UserModel(
      name: 'Demo User',
      email: 'user@example.com',
      photoURL: '',
    );
    notifyListeners();
  }

  void register({required String name, required String email}) {
    _isAuthenticated = true;
    _user = UserModel(
      name: name.isEmpty ? 'New User' : name,
      email: email.isEmpty ? 'user@example.com' : email,
      photoURL: '',
    );
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }
}

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
