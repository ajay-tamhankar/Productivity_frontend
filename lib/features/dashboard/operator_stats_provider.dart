import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_services/api_client.dart';

class OperatorRejectionReason {
  final String reason;
  final int count;
  final double weight;

  const OperatorRejectionReason({
    required this.reason,
    required this.count,
    required this.weight,
  });

  factory OperatorRejectionReason.fromJson(Map<String, dynamic> json) {
    return OperatorRejectionReason(
      reason: (json['reason'] ?? '').toString(),
      count: _toInt(json['count']),
      weight: _toDouble(json['weight']),
    );
  }
}

class OperatorStats {
  final int totalProduction;
  final double totalProductionWeight;
  final int totalRejection;
  final double totalRejectionWeight;
  final double totalRunningHours;
  final double totalRunningHoursWeight;
  final double averagePartsPerHour;
  final List<OperatorRejectionReason> rejectionReasons;

  const OperatorStats({
    required this.totalProduction,
    required this.totalProductionWeight,
    required this.totalRejection,
    required this.totalRejectionWeight,
    required this.totalRunningHours,
    required this.totalRunningHoursWeight,
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
      totalProductionWeight:
          _toDouble(json['totalProductionWeight'] ?? json['totalProductionweight']),
      totalRejection: _toInt(json['totalRejection']),
      totalRejectionWeight:
          _toDouble(json['totalRejectionWeight'] ?? json['totalRejectionweight']),
      totalRunningHours: _toDouble(json['totalRunningHours']),
      totalRunningHoursWeight:
          _toDouble(json['totalRunningHoursWeight'] ?? json['totalRunningHoursweight']),
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
