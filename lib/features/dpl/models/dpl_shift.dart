import '_json_helpers.dart';

/// A shift definition (`dpl.dpl_shifts`).
///
/// `start_time` / `end_time` are stored as `HH:mm[:ss]` strings on the
/// server — kept as raw strings on the client because we only render
/// them; the wrap-midnight handling is server-side.
class DplShift {
  final int id;
  final String code;
  final String name;
  final String startTime;
  final String endTime;
  final bool isActive;

  const DplShift({
    required this.id,
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  factory DplShift.fromJson(Map<String, dynamic> json) {
    return DplShift(
      id: parseIntOr(json['id']),
      code: parseStringOr(json['code']),
      name: parseStringOr(json['name']),
      startTime: parseStringOr(json['start_time'] ?? json['startTime']),
      endTime: parseStringOr(json['end_time'] ?? json['endTime']),
      isActive: json['is_active'] is bool
          ? json['is_active'] as bool
          : json['isActive'] is bool
              ? json['isActive'] as bool
              : true,
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'code': code,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
      };

  Map<String, dynamic> toUpdateJson() => {
        'code': code,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'is_active': isActive,
      };

  /// "06:00 → 14:00"
  String get windowLabel {
    final s = _short(startTime);
    final e = _short(endTime);
    if (s.isEmpty || e.isEmpty) return '';
    return '$s → $e';
  }

  static String _short(String hms) {
    final t = hms.trim();
    if (t.length >= 5) return t.substring(0, 5);
    return t;
  }

  DplShift copyWith({
    int? id,
    String? code,
    String? name,
    String? startTime,
    String? endTime,
    bool? isActive,
  }) {
    return DplShift(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
    );
  }
}
