import '_json_helpers.dart';

/// Preview returned by `POST /plans/upload-excel`.
///
/// Backends in the wild use a few different shapes. We accept:
///
///   1. `{ "preview": [ {row}, {row}, ... ] }` — the **real DPL backend**.
///      Rows are flat; we group them into machine sections by
///      `machine_id`/`machine_name`.
///
///   2. `{ "machines": [ {machine_id, machine_name, rows: [...]} ],
///         "warnings": [...] }` — older / grouped shape (kept for
///      forwards compatibility).
///
///   3. A bare array of rows (no envelope) — same as case 1 but unwrapped.
class DplExcelPreview {
  final List<DplExcelMachineSection> machines;
  final List<DplExcelWarning> warnings;

  const DplExcelPreview({
    required this.machines,
    required this.warnings,
  });

  factory DplExcelPreview.fromJson(Map<String, dynamic> json) {
    // ---- warnings ----
    final rawWarnings = json['warnings'];
    final warnings = rawWarnings is List
        ? rawWarnings
            .whereType<Map>()
            .map((e) => DplExcelWarning.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <DplExcelWarning>[];

    // ---- machines / preview rows ----
    // Try the "grouped machines" shape first.
    final rawMachines = json['machines'];
    if (rawMachines is List && rawMachines.isNotEmpty) {
      final sections = rawMachines
          .whereType<Map>()
          .map((e) => DplExcelMachineSection.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
      return DplExcelPreview(machines: sections, warnings: warnings);
    }

    // Otherwise look for the flat `preview` array and group it ourselves.
    List<dynamic> flatRows = const [];
    for (final key in const ['preview', 'rows', 'items', 'plans']) {
      final v = json[key];
      if (v is List) {
        flatRows = v;
        break;
      }
    }

    final sections = _groupRowsIntoSections(flatRows);
    return DplExcelPreview(machines: sections, warnings: warnings);
  }

  /// Builds a preview from a bare array of rows.
  factory DplExcelPreview.fromRows(List<dynamic> rows) {
    return DplExcelPreview(
      machines: _groupRowsIntoSections(rows),
      warnings: const [],
    );
  }

  bool get isEmpty => machines.isEmpty;
  int get totalRowCount =>
      machines.fold<int>(0, (sum, m) => sum + m.rows.length);

  static List<DplExcelMachineSection> _groupRowsIntoSections(
    List<dynamic> rawRows,
  ) {
    final byMachine = <int, _MachineBucket>{};
    final unknownBucket = _MachineBucket(machineId: 0, machineName: '');

    for (final raw in rawRows) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);

      final machineId = parseIntOr(
        map['machine_id'] ?? map['machineId'],
        -1,
      );
      final machineName = parseStringOr(
        map['machine_name'] ?? map['machineName'] ?? map['machine'],
      );

      final row = DplExcelPlanRow.fromJson(map);

      if (machineId > 0) {
        final bucket = byMachine.putIfAbsent(
          machineId,
          () => _MachineBucket(
            machineId: machineId,
            machineName: machineName,
          ),
        );
        // Prefer a non-empty name if we discover one later.
        if (bucket.machineName.isEmpty && machineName.isNotEmpty) {
          bucket.machineName = machineName;
        }
        bucket.rows.add(row);
      } else {
        unknownBucket.rows.add(row);
      }
    }

    final sections = byMachine.values
        .map((b) => DplExcelMachineSection(
              machineId: b.machineId,
              machineName: b.machineName,
              rows: b.rows,
            ))
        .toList();

    if (unknownBucket.rows.isNotEmpty) {
      sections.add(DplExcelMachineSection(
        machineId: 0,
        machineName: 'Unmapped rows',
        rows: unknownBucket.rows,
      ));
    }

    return sections;
  }
}

class _MachineBucket {
  final int machineId;
  String machineName;
  final List<DplExcelPlanRow> rows = [];

  _MachineBucket({
    required this.machineId,
    required this.machineName,
  });
}

class DplExcelMachineSection {
  final int machineId;
  final String machineName;
  final List<DplExcelPlanRow> rows;

  const DplExcelMachineSection({
    required this.machineId,
    required this.machineName,
    required this.rows,
  });

  factory DplExcelMachineSection.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'] ?? json['items'];
    final rows = rawRows is List
        ? rawRows
            .whereType<Map>()
            .map((e) =>
                DplExcelPlanRow.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DplExcelPlanRow>[];

    return DplExcelMachineSection(
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      machineName: parseStringOr(
        json['machine_name'] ?? json['machineName'] ?? json['machine'],
      ),
      rows: rows,
    );
  }

  int get totalPlanQty =>
      rows.fold<int>(0, (acc, r) => acc + (r.partId == null ? 0 : r.planQty));
}

class DplExcelPlanRow {
  int planNo;
  int? partId;
  String partNumber;
  String partDescription;
  int planQty;
  int sequence;
  String? warning;

  DplExcelPlanRow({
    required this.planNo,
    required this.partNumber,
    required this.partDescription,
    required this.planQty,
    required this.sequence,
    this.partId,
    this.warning,
  });

  factory DplExcelPlanRow.fromJson(Map<String, dynamic> json) {
    // Part info may arrive flat OR under a nested `part` object.
    Map<String, dynamic> part = const {};
    final rawPart = json['part'];
    if (rawPart is Map) part = Map<String, dynamic>.from(rawPart);

    String pickStr(List<dynamic> candidates) {
      for (final c in candidates) {
        if (c == null) continue;
        final s = c.toString();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    return DplExcelPlanRow(
      planNo: parseIntOr(json['plan_no'] ?? json['planNo']),
      partId: parseIntOrNull(
        json['part_id'] ?? json['partId'] ?? part['id'],
      ),
      partNumber: pickStr([
        json['part_number'],
        json['partNumber'],
        json['customer_part_no'],
        json['customerPartNo'],
        part['customer_part_no'],
        part['part_number'],
      ]),
      partDescription: pickStr([
        json['part_description'],
        json['partDescription'],
        json['description'],
        part['description'],
      ]),
      planQty: parseIntOr(json['plan_qty'] ?? json['planQty'] ?? json['qty']),
      sequence: parseIntOr(json['sequence'] ?? json['seq']),
      warning: json['warning']?.toString() ?? json['error']?.toString(),
    );
  }
}

class DplExcelWarning {
  final String message;
  final int? row;
  final String? field;

  const DplExcelWarning({
    required this.message,
    this.row,
    this.field,
  });

  factory DplExcelWarning.fromJson(Map<String, dynamic> json) {
    return DplExcelWarning(
      message: parseStringOr(json['message']),
      row: parseIntOrNull(json['row']),
      field: json['field']?.toString(),
    );
  }
}
