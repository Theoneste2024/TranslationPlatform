class UserModel {
  final int? id;
  final String email;
  final String username;
  final String name;
  final String phoneNumber;
  final String gender;
  final bool emailVerified;

  const UserModel({
    this.id,
    required this.email,
    required this.username,
    required this.name,
    required this.phoneNumber,
    required this.gender,
    required this.emailVerified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? '';
    final email = json['email']?.toString() ?? '';
    final displayName = json['name']?.toString() ?? '';
    return UserModel(
      id: json['id'] is int ? json['id'] as int : null,
      email: email,
      username: username,
      name: displayName.isNotEmpty ? displayName : username,
      phoneNumber: json['phone_number']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      emailVerified: json['email_verified'] == true,
    );
  }
}
