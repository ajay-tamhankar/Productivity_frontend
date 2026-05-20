import '_json_helpers.dart';

class DplMachine {
  final int id;
  final String code;
  final String name;
  final String description;
  final bool isActive;

  const DplMachine({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.isActive = true,
  });

  factory DplMachine.fromJson(Map<String, dynamic> json) {
    return DplMachine(
      id: parseIntOr(json['id']),
      // Backend uses `machine_code` / `machine_name`. We also accept
      // shorter aliases in case other surfaces emit them.
      code: parseStringOr(
        json['machine_code'] ?? json['machineCode'] ?? json['code'],
      ),
      name: parseStringOr(
        json['machine_name'] ?? json['machineName'] ?? json['name'],
      ),
      description: parseStringOr(json['description']),
      isActive: json['is_active'] is bool
          ? json['is_active'] as bool
          : json['isActive'] is bool
              ? json['isActive'] as bool
              : true,
    );
  }

  /// Payload shape expected by `POST /manager/machines`.
  Map<String, dynamic> toCreateJson() => {
        'machine_code': code,
        'machine_name': name,
        if (description.isNotEmpty) 'description': description,
      };

  /// Payload shape expected by `PUT /manager/machines/:id`.
  Map<String, dynamic> toUpdateJson() => {
        'machine_code': code,
        'machine_name': name,
        'description': description,
        'is_active': isActive,
      };

  DplMachine copyWith({
    int? id,
    String? code,
    String? name,
    String? description,
    bool? isActive,
  }) {
    return DplMachine(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
}
