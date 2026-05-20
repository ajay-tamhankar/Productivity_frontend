// Shared, defensive JSON parsing helpers used across DPL models.
// Mirrors the manual-parse style already used elsewhere in this app
// (e.g. lib/features/dashboard/admin_dashboard_provider.dart).

int parseIntOr(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is bool) return value ? 1 : 0;
  return int.tryParse(value.toString()) ?? fallback;
}

int? parseIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

double parseDoubleOr(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

String parseStringOr(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

DateTime? parseDateTimeOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
