import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_services/api_client.dart';
import '../../data/models/production_entry_model.dart';

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
              .map(
                (e) => OperatorRejectionReason.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : <OperatorRejectionReason>[];

    return OperatorStats(
      totalProduction: _toInt(json['totalProduction']),
      totalProductionWeight: _toDouble(
        json['totalProductionWeight'] ?? json['totalProductionweight'],
      ),
      totalRejection: _toInt(json['totalRejection']),
      totalRejectionWeight: _toDouble(
        json['totalRejectionWeight'] ?? json['totalRejectionweight'],
      ),
      totalRunningHours: _toDouble(json['totalRunningHours']),
      totalRunningHoursWeight: _toDouble(
        json['totalRunningHoursWeight'] ?? json['totalRunningHoursweight'],
      ),
      averagePartsPerHour: _toDouble(json['averagePartsPerHour']),
      rejectionReasons: reasons,
    );
  }
}

class OperatorProductivityMetric {
  final int totalProduction;
  final double totalWeight;
  final double totalRunningHours;

  const OperatorProductivityMetric({
    required this.totalProduction,
    required this.totalWeight,
    required this.totalRunningHours,
  });

  double get piecesPerHour =>
      totalRunningHours <= 0 ? 0 : totalProduction / totalRunningHours;

  double get kgPerHour =>
      totalRunningHours <= 0 ? 0 : totalWeight / totalRunningHours;

  bool get hasData => totalRunningHours > 0;
}

class OperatorShiftProductivity {
  final String shift;
  final String entryDate;
  final OperatorProductivityMetric metric;

  const OperatorShiftProductivity({
    required this.shift,
    required this.entryDate,
    required this.metric,
  });
}

class OperatorProductivitySnapshot {
  final OperatorProductivityMetric yesterday;
  final OperatorShiftProductivity? previousShift;

  const OperatorProductivitySnapshot({
    required this.yesterday,
    required this.previousShift,
  });
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

final operatorProductivitySnapshotProvider =
    FutureProvider<OperatorProductivitySnapshot>((ref) async {
      final client = ref.read(apiClientProvider);
      final entries = <ProductionEntryModel>[];

      for (var page = 1; page <= 10; page++) {
        final response = await client.get(
          '/production/operator-feed?page=$page&limit=10',
        );
        final raw = response.data;
        final pageEntries = _operatorFeedEntries(raw);
        entries.addAll(pageEntries);

        var hasMore = pageEntries.length >= 10;
        if (raw is Map && raw['totalPages'] != null) {
          final totalPages = int.tryParse(raw['totalPages'].toString()) ?? page;
          hasMore = page < totalPages;
        }
        if (!hasMore) break;
      }

      return _buildProductivitySnapshot(entries);
    });

List<ProductionEntryModel> _operatorFeedEntries(dynamic raw) {
  List<dynamic> dataList;
  if (raw is List) {
    dataList = raw;
  } else if (raw is Map && raw['data'] is List) {
    dataList = raw['data'] as List<dynamic>;
  } else if (raw is Map && raw['id'] != null) {
    dataList = [raw];
  } else {
    dataList = [];
  }

  return dataList
      .whereType<Map>()
      .map((j) => ProductionEntryModel.fromJson(Map<String, dynamic>.from(j)))
      .toList();
}

OperatorProductivitySnapshot _buildProductivitySnapshot(
  List<ProductionEntryModel> entries,
) {
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  var yesterdayProduction = 0;
  var yesterdayWeight = 0.0;
  var yesterdayHours = 0.0;

  for (final entry in entries) {
    final entryDate = _entryLocalDate(entry);
    if (entryDate == null || !_isSameDay(entryDate, yesterday)) continue;
    yesterdayProduction += entry.actualQuantity;
    yesterdayWeight += entry.weightInKGs;
    yesterdayHours += entry.runningHours;
  }

  final sortedEntries = [...entries]
    ..sort((a, b) {
      final aDate =
          _entryLocalDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          _entryLocalDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

  ProductionEntryModel? previousEntry;
  for (final entry in sortedEntries) {
    if (entry.runningHours > 0) {
      previousEntry = entry;
      break;
    }
  }

  return OperatorProductivitySnapshot(
    yesterday: OperatorProductivityMetric(
      totalProduction: yesterdayProduction,
      totalWeight: yesterdayWeight,
      totalRunningHours: yesterdayHours,
    ),
    previousShift: previousEntry == null
        ? null
        : OperatorShiftProductivity(
            shift: previousEntry.shift,
            entryDate: previousEntry.entryDate,
            metric: OperatorProductivityMetric(
              totalProduction: previousEntry.actualQuantity,
              totalWeight: previousEntry.weightInKGs,
              totalRunningHours: previousEntry.runningHours,
            ),
          ),
  );
}

DateTime? _entryLocalDate(ProductionEntryModel entry) {
  final startTime = DateTime.tryParse(entry.startTime);
  if (startTime != null) return startTime.toLocal();

  final entryDate = DateTime.tryParse(entry.entryDate);
  return entryDate?.toLocal();
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
