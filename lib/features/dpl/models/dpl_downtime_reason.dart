import '_json_helpers.dart';

class DplDowntimeReason {
  final int id;
  final String code;
  final String name;
  /// "planned" | "unplanned"
  final String category;
  final bool isActive;

  const DplDowntimeReason({
    required this.id,
    required this.code,
    required this.name,
    this.category = 'unplanned',
    this.isActive = true,
  });

  factory DplDowntimeReason.fromJson(Map<String, dynamic> json) {
    return DplDowntimeReason(
      id: parseIntOr(json['id']),
      code: parseStringOr(
        json['reason_code'] ?? json['reasonCode'] ?? json['code'],
      ),
      name: parseStringOr(
        json['reason_name'] ?? json['reasonName'] ?? json['name'],
      ),
      category:
          parseStringOr(json['category'], 'unplanned').toLowerCase(),
      isActive: json['is_active'] is bool
          ? json['is_active'] as bool
          : json['isActive'] is bool
              ? json['isActive'] as bool
              : true,
    );
  }

  Map<String, dynamic> toJsonForWrite() => {
        'reason_code': code,
        'reason_name': name,
        'category': category,
        'is_active': isActive,
      };

  DplDowntimeReason copyWith({
    int? id,
    String? code,
    String? name,
    String? category,
    bool? isActive,
  }) {
    return DplDowntimeReason(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
    );
  }
}
