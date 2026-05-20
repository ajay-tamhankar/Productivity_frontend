import '_json_helpers.dart';

class DplSupervisor {
  final int userId;
  final String name;
  final String email;
  final String role;

  const DplSupervisor({
    required this.userId,
    required this.name,
    this.email = '',
    this.role = '',
  });

  factory DplSupervisor.fromJson(Map<String, dynamic> json) {
    return DplSupervisor(
      userId: parseIntOr(json['user_id'] ?? json['id'] ?? json['userId']),
      name: parseStringOr(json['name'] ?? json['full_name'] ?? json['fullName']),
      email: parseStringOr(json['email']),
      role: parseStringOr(json['role']),
    );
  }
}
