import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/api_services/api_client.dart';

part 'admin_dashboard_provider.g.dart';

class DashboardKPI {
  final int totalProduction;
  final int totalRejection;
  final double totalRunningHours;
  final double averagePartsPerHour;

  DashboardKPI({
    this.totalProduction = 0,
    this.totalRejection = 0,
    this.totalRunningHours = 0,
    this.averagePartsPerHour = 0,
  });

  factory DashboardKPI.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double parseDouble(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return DashboardKPI(
      totalProduction: parseInt(json['totalProduction']),
      totalRejection: parseInt(json['totalRejection']),
      totalRunningHours: parseDouble(json['totalRunningHours']),
      averagePartsPerHour: parseDouble(json['averagePartsPerHour']),
    );
  }
}

class ShiftProduction {
  final String shift;
  final int totalQuantity;

  ShiftProduction({required this.shift, required this.totalQuantity});

  factory ShiftProduction.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ShiftProduction(
      shift: json['shift'] ?? '',
      totalQuantity: parseInt(json['totalQuantity']),
    );
  }
}

class RejectionReasonData {
  final String reason;
  final int count;

  RejectionReasonData({required this.reason, required this.count});

  factory RejectionReasonData.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return RejectionReasonData(
      reason: json['reason'] ?? '',
      count: parseInt(json['count']),
    );
  }
}

class OperatorPerformanceData {
  final String name;
  final int value;

  OperatorPerformanceData({
    required this.name,
    required this.value,
  });

  factory OperatorPerformanceData.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return OperatorPerformanceData(
      name: (json['name'] ?? '').toString(),
      value: parseInt(json['value']),
    );
  }
}

class MachineOutputData {
  final String name;
  final String machineNumber;
  final int value;

  MachineOutputData({
    required this.name,
    required this.machineNumber,
    required this.value,
  });

  factory MachineOutputData.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return MachineOutputData(
      name: (json['name'] ?? '').toString(),
      machineNumber: (json['machineNumber'] ?? '').toString(),
      value: parseInt(json['value']),
    );
  }
}

class AdminDashboardState {
  final DashboardKPI kpi;
  final List<ShiftProduction> shiftProduction;
  final List<RejectionReasonData> rejectionReasons;
  final List<OperatorPerformanceData> operatorPerformance;
  final List<MachineOutputData> machineOutput;
  final DateTime? startDate;
  final DateTime? endDate;

  AdminDashboardState({
    required this.kpi,
    required this.shiftProduction,
    required this.rejectionReasons,
    this.operatorPerformance = const [],
    this.machineOutput = const [],
    this.startDate,
    this.endDate,
  });
}

@riverpod
class AdminDashboardController extends _$AdminDashboardController {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  FutureOr<AdminDashboardState> build() async {
    return _fetchData(startDate: _startDate, endDate: _endDate);
  }

  Future<AdminDashboardState> _fetchData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final client = ref.read(apiClientProvider);
    final dateQuery = <String, dynamic>{
      if (startDate != null) 'startDate': _toYmd(startDate),
      if (endDate != null) 'endDate': _toYmd(endDate),
    };

    final futures = await Future.wait([
      client.get('/dashboard/kpi'),
      client.get('/dashboard/shift-production'),
      client.get('/dashboard/rejection-reasons'),
      client.get('/dashboard/operator-performance', queryParameters: dateQuery),
      client.get('/dashboard/machine-output', queryParameters: dateQuery),
    ]);

    final kpiJson = futures[0].data;
    final shiftRaw = futures[1].data;
    final rejectionRaw = futures[2].data;
    final operatorRaw = futures[3].data;
    final machineRaw = futures[4].data;
    final shiftJsonList = shiftRaw is List ? shiftRaw : <dynamic>[];
    final rejectionJsonList = rejectionRaw is List ? rejectionRaw : <dynamic>[];
    final operatorJsonList = operatorRaw is List ? operatorRaw : <dynamic>[];
    final machineJsonList = machineRaw is List ? machineRaw : <dynamic>[];
    final kpiMap = kpiJson is Map
        ? Map<String, dynamic>.from(kpiJson as Map)
        : <String, dynamic>{};

    return AdminDashboardState(
      kpi: DashboardKPI.fromJson(kpiMap),
      shiftProduction: shiftJsonList
          .whereType<Map>()
          .map((e) => ShiftProduction.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      rejectionReasons: rejectionJsonList
          .whereType<Map>()
          .map((e) => RejectionReasonData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      operatorPerformance: operatorJsonList
          .whereType<Map>()
          .map((e) => OperatorPerformanceData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      machineOutput: machineJsonList
          .whereType<Map>()
          .map((e) => MachineOutputData.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchData(startDate: _startDate, endDate: _endDate),
    );
  }

  Future<void> setDateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _startDate = startDate;
    _endDate = endDate;
    await refresh();
  }

  String _toYmd(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
