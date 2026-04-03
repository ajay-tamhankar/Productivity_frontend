import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_services/api_client.dart';

class OperatorRejectionReason {
  final String reason;
  final int count;

  const OperatorRejectionReason({
    required this.reason,
    required this.count,
  });

  factory OperatorRejectionReason.fromJson(Map<String, dynamic> json) {
    return OperatorRejectionReason(
      reason: (json['reason'] ?? '').toString(),
      count: _toInt(json['count']),
    );
  }
}

class OperatorStats {
  final int totalProduction;
  final int totalRejection;
  final double totalRunningHours;
  final double averagePartsPerHour;
  final List<OperatorRejectionReason> rejectionReasons;

  const OperatorStats({
    required this.totalProduction,
    required this.totalRejection,
    required this.totalRunningHours,
    required this.averagePartsPerHour,
    required this.rejectionReasons,
  });

  factory OperatorStats.fromJson(Map<String, dynamic> json) {
    final reasonsJson = json['rejectionReasons'];
    final reasons = (reasonsJson is List)
        ? reasonsJson
            .whereType<Map>()
            .map((e) => OperatorRejectionReason.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <OperatorRejectionReason>[];

    return OperatorStats(
      totalProduction: _toInt(json['totalProduction']),
      totalRejection: _toInt(json['totalRejection']),
      totalRunningHours: _toDouble(json['totalRunningHours']),
      averagePartsPerHour: _toDouble(json['averagePartsPerHour']),
      rejectionReasons: reasons,
    );
  }
}

final operatorStatsProvider = FutureProvider<OperatorStats>((ref) async {
  final client = ref.read(apiClientProvider);

  final response = await client.get('/dashboard/operator-stats');
  final data = response.data;

  if (data is Map<String, dynamic>) {
    return OperatorStats.fromJson(data);
  }

  if (data is Map) {
    return OperatorStats.fromJson(Map<String, dynamic>.from(data));
  }

  throw Exception('Invalid operator stats response.');
});

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '0') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '0') ?? 0.0;
}
