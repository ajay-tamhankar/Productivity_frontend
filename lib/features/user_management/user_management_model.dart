class ManagedUser {
  final String id;
  final String username;
  final String name;
  final String role;

  const ManagedUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    String read(dynamic value) => (value ?? '').toString().trim();

    return ManagedUser(
      id: read(json['id']).isNotEmpty ? read(json['id']) : read(json['_id']),
      username: read(json['username']),
      name: read(json['name']),
      role: read(json['role']).toUpperCase(),
    );
  }
}
