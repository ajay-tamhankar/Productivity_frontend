import '_json_helpers.dart';
import 'dpl_machine.dart';
import 'dpl_manpower_log.dart';
import 'dpl_shift.dart';

/// Full payload of `GET /manager/reports/dpl-chart?from=&to=` — every
/// data point needed to render the company's Daily Production Loading
/// Chart spreadsheet in a single round-trip.
class DplMonthlyChart {
  final DateTime from;
  final DateTime to;
  final List<DateTime> days;
  final List<DplShift> shifts;
  final List<DplMachine> machines;
  /// One entry per (machine, shift) combination, with a per-day cell array.
  final List<DplChartRow> rows;
  /// Per-cell manpower counts. May be empty until headcounts get entered.
  final List<DplManpowerLog> manpower;
  /// Per (date, shift) lost-work-hours due to breakdowns, with per-machine split.
  final List<DplChartBreakdownRow> breakdownHours;
  final DplChartCumulative cumulative;

  const DplMonthlyChart({
    required this.from,
    required this.to,
    required this.days,
    required this.shifts,
    required this.machines,
    required this.rows,
    required this.manpower,
    required this.breakdownHours,
    required this.cumulative,
  });

  factory DplMonthlyChart.empty(DateTime from, DateTime to) =>
      DplMonthlyChart(
        from: from,
        to: to,
        days: const [],
        shifts: const [],
        machines: const [],
        rows: const [],
        manpower: const [],
        breakdownHours: const [],
        cumulative: DplChartCumulative.empty(),
      );

  factory DplMonthlyChart.fromJson(Map<String, dynamic> json) {
    List<dynamic> listAt(String key) {
      final v = json[key];
      return v is List ? v : const <dynamic>[];
    }

    final days = listAt('days')
        .map((e) => parseDateTimeOrNull(e))
        .whereType<DateTime>()
        .toList();

    final shifts = listAt('shifts')
        .whereType<Map>()
        .map((e) => DplShift.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final machines = listAt('machines')
        .whereType<Map>()
        .map((e) => DplMachine.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rows = listAt('rows')
        .whereType<Map>()
        .map((e) => DplChartRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final manpower = listAt('manpower')
        .whereType<Map>()
        .map((e) => DplManpowerLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final breakdownHours = listAt('breakdown_hours')
        .whereType<Map>()
        .map((e) =>
            DplChartBreakdownRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawCumulative = json['cumulative'];
    final cumulative = rawCumulative is Map
        ? DplChartCumulative.fromJson(Map<String, dynamic>.from(rawCumulative))
        : DplChartCumulative.empty();

    final from = parseDateTimeOrNull(json['from']) ??
        (days.isNotEmpty ? days.first : DateTime.now());
    final to = parseDateTimeOrNull(json['to']) ??
        (days.isNotEmpty ? days.last : DateTime.now());

    return DplMonthlyChart(
      from: from,
      to: to,
      days: days,
      shifts: shifts,
      machines: machines,
      rows: rows,
      manpower: manpower,
      breakdownHours: breakdownHours,
      cumulative: cumulative,
    );
  }

  /// O(1) cell lookup helper. Returns the per-day cell for the given
  /// (machine, shift, date) — or null if absent.
  DplChartCell? cellFor({
    required int machineId,
    required int shiftId,
    required DateTime date,
  }) {
    for (final row in rows) {
      if (row.machineId != machineId || row.shiftId != shiftId) continue;
      for (final c in row.daily) {
        if (_sameDay(c.date, date)) return c;
      }
      return null;
    }
    return null;
  }

  /// Convenience — headcount for (date, shift, machineId optional).
  int? headcountFor({
    required DateTime date,
    required int shiftId,
    int? machineId,
  }) {
    for (final m in manpower) {
      if (!_sameDay(m.date, date)) continue;
      if (m.shiftId != shiftId) continue;
      if (m.machineId == machineId) return m.headcount;
    }
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A `rows[]` entry — one per (machine_id, shift_id) combination.
class DplChartRow {
  final int machineId;
  final int shiftId;
  final List<DplChartCell> daily;
  final DplChartTotals totals;

  const DplChartRow({
    required this.machineId,
    required this.shiftId,
    required this.daily,
    required this.totals,
  });

  factory DplChartRow.fromJson(Map<String, dynamic> json) {
    final rawDaily = json['daily'];
    final daily = rawDaily is List
        ? rawDaily
            .whereType<Map>()
            .map((e) => DplChartCell.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DplChartCell>[];

    final rawTotals = json['totals'];
    final totals = rawTotals is Map
        ? DplChartTotals.fromJson(Map<String, dynamic>.from(rawTotals))
        : DplChartTotals.empty();

    return DplChartRow(
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      shiftId: parseIntOr(json['shift_id'] ?? json['shiftId']),
      daily: daily,
      totals: totals,
    );
  }
}

class DplChartCell {
  final DateTime date;
  final int planQty;
  final int actualQty;
  final int downtimeMinutes;

  const DplChartCell({
    required this.date,
    required this.planQty,
    required this.actualQty,
    required this.downtimeMinutes,
  });

  factory DplChartCell.fromJson(Map<String, dynamic> json) {
    return DplChartCell(
      date: parseDateTimeOrNull(json['date']) ?? DateTime.now(),
      planQty: parseIntOr(json['plan_qty'] ?? json['planQty']),
      actualQty: parseIntOr(json['actual_qty'] ?? json['actualQty']),
      downtimeMinutes:
          parseIntOr(json['downtime_minutes'] ?? json['downtimeMinutes']),
    );
  }

  int get variance => actualQty - planQty;

  double get completionPct =>
      planQty <= 0 ? 0 : (actualQty / planQty).clamp(0.0, 1.0);
}

class DplChartTotals {
  final int planQty;
  final int actualQty;
  final int downtimeMinutes;

  const DplChartTotals({
    required this.planQty,
    required this.actualQty,
    required this.downtimeMinutes,
  });

  factory DplChartTotals.fromJson(Map<String, dynamic> json) {
    return DplChartTotals(
      planQty: parseIntOr(json['plan_qty'] ?? json['planQty']),
      actualQty: parseIntOr(json['actual_qty'] ?? json['actualQty']),
      downtimeMinutes:
          parseIntOr(json['downtime_minutes'] ?? json['downtimeMinutes']),
    );
  }

  factory DplChartTotals.empty() => const DplChartTotals(
        planQty: 0,
        actualQty: 0,
        downtimeMinutes: 0,
      );

  double get completionPct =>
      planQty <= 0 ? 0 : (actualQty / planQty).clamp(0.0, 1.0);
}

class DplChartBreakdownRow {
  final DateTime date;
  final int shiftId;
  final double hours;
  /// machineId → hours map.
  final Map<int, double> byMachine;

  const DplChartBreakdownRow({
    required this.date,
    required this.shiftId,
    required this.hours,
    required this.byMachine,
  });

  factory DplChartBreakdownRow.fromJson(Map<String, dynamic> json) {
    final byMachine = <int, double>{};
    final raw = json['by_machine'] ?? json['byMachine'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final id = int.tryParse(entry.key.toString());
        if (id == null) continue;
        final v = entry.value;
        if (v is num) {
          byMachine[id] = v.toDouble();
        } else if (v != null) {
          byMachine[id] = double.tryParse(v.toString()) ?? 0;
        }
      }
    }

    return DplChartBreakdownRow(
      date: parseDateTimeOrNull(json['date']) ?? DateTime.now(),
      shiftId: parseIntOr(json['shift_id'] ?? json['shiftId']),
      hours: parseDoubleOr(json['hours']),
      byMachine: byMachine,
    );
  }
}

class DplChartCumulative {
  final int planQty;
  final int actualQty;
  final double achievementPct;
  final int totalDowntimeMinutes;
  final double totalManHours;
  final double totalLostManHours;
  final double lostPct;

  const DplChartCumulative({
    required this.planQty,
    required this.actualQty,
    required this.achievementPct,
    required this.totalDowntimeMinutes,
    required this.totalManHours,
    required this.totalLostManHours,
    required this.lostPct,
  });

  factory DplChartCumulative.fromJson(Map<String, dynamic> json) {
    double pct(String a, String b) {
      var v = parseDoubleOr(json[a] ?? json[b], -1);
      if (v < 0) v = 0;
      if (v > 1) v = v / 100;
      return v.clamp(0.0, 1.0).toDouble();
    }

    return DplChartCumulative(
      planQty: parseIntOr(json['plan_qty'] ?? json['planQty']),
      actualQty: parseIntOr(json['actual_qty'] ?? json['actualQty']),
      achievementPct: pct('achievement_pct', 'achievementPct'),
      totalDowntimeMinutes: parseIntOr(
        json['total_downtime_minutes'] ?? json['totalDowntimeMinutes'],
      ),
      totalManHours:
          parseDoubleOr(json['total_man_hours'] ?? json['totalManHours']),
      totalLostManHours: parseDoubleOr(
        json['total_lost_man_hours'] ?? json['totalLostManHours'],
      ),
      lostPct: pct('lost_pct', 'lostPct'),
    );
  }

  factory DplChartCumulative.empty() => const DplChartCumulative(
        planQty: 0,
        actualQty: 0,
        achievementPct: 0,
        totalDowntimeMinutes: 0,
        totalManHours: 0,
        totalLostManHours: 0,
        lostPct: 0,
      );
}
