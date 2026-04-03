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
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
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
