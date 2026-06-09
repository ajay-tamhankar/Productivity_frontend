import '_json_helpers.dart';

/// Tenant the logged-in DPL user belongs to. Every authenticated DPL
/// request is auto-filtered server-side by the org encoded in the JWT;
/// the frontend stores this so the active tenant can be shown in the
/// AppBar / profile drawer and so we can detect ORG_MISMATCH errors.
class DplOrganization {
  final int id;
  final String code;
  final String name;

  const DplOrganization({
    required this.id,
    required this.code,
    required this.name,
  });

  factory DplOrganization.fromJson(Map<String, dynamic> json) {
    return DplOrganization(
      id: parseIntOr(json['id']),
      code: parseStringOr(json['code']),
      name: parseStringOr(json['name']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
      };

  /// Short label used in the AppBar pill — prefers `name`, falls back to
  /// `code`, then to a generic "Org #N" so a stale record can never
  /// render as an empty pill.
  String get displayLabel {
    if (name.trim().isNotEmpty) return name.trim();
    if (code.trim().isNotEmpty) return code.trim();
    return 'Org #$id';
  }
}
