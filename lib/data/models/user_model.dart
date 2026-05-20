import '../../core/constants/app_constants.dart';

class UserModel {
  final String id;
  final String username;
  final String name;
  final String role;
  final String? token;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['userId'] ?? json['_id'] ?? '';
    final rawUsername = json['username'] ?? json['email'] ?? '';
    final rawName =
        json['name'] ?? json['fullName'] ?? json['displayName'] ?? rawUsername;
    final rawRole = json['role'] ?? json['userRole'] ?? '';

    return UserModel(
      id: rawId.toString(),
      username: rawUsername.toString(),
      name: rawName.toString(),
      role: AppConstants.normalizeRole(rawRole.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role,
    };
  }
}
