import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../core/dpl_api_service.dart';
import '../../core/dpl_constants.dart';
import '../../manager/services/dpl_excel_style.dart';
import '../../models/dpl_plant.dart';

/// One part identity row in the monthly Buffer Creation Plan.
class DplBufferPlanPart {
  final int partId;
  final String customerPn;
  final String description;
  final String partName;

  const DplBufferPlanPart({
    required this.partId,
    required this.customerPn,
    required this.description,
    required this.partName,
  });

  /// Best display code for the leading "Customer Part No." column —
  /// prefers the customer P/N, then the short description, then a
  /// `Part #id` fallback so the row never renders blank.
  String get pnLabel {
    if (customerPn.trim().isNotEmpty) return customerPn.trim();
    if (description.trim().isNotEmpty) return description.trim();
    return 'Part #$partId';
  }

  String get descLabel {
    if (description.trim().isNotEmpty) return description.trim();
    if (partName.trim().isNotEmpty) return partName.trim();
    return '';
  }
}

/// The five per-(part, day) metrics that make up one cell block of the
/// Buffer Creation Plan. All nullable — a `null` renders as a blank cell
/// (e.g. no production that day, or the customer snapshot wasn't entered).
///
/// Naming maps the on-screen / API field to the customer's spreadsheet
/// column label:
///   * [opnStockTml]  → "Opn Stock at TML"   (roll-forward from a seed)
///   * [opnStockGa]   → "Opn Stock at GA"    (roll-forward from a seed)
///   * [productionGa] → "Production at GA"   (daily production qty)
///   * [dispatchGa]   → "Dispatch From GA"   (qty dispatched that day)
///   * [customerPlan] → "Customer Plan"      (customer's plan for the day)
class DplBufferPlanCell {
  final int? opnStockTml;
  final int? opnStockGa;
  final int? productionGa;
  final int? dispatchGa;
  final int? customerPlan;

  const DplBufferPlanCell({
    this.opnStockTml,
    this.opnStockGa,
    this.productionGa,
    this.dispatchGa,
    this.customerPlan,
  });
}

/// One plant's matrix — becomes one worksheet in the workbook.
class DplBufferPlanPlant {
  final String plantCode;
  final String plantName;

  /// Parts sorted by customer P/N then description.
  final List<DplBufferPlanPart> parts;

  /// `cells[partId][dayIndex]` — same length as the workbook's days list.
  final Map<int, List<DplBufferPlanCell>> cells;

  const DplBufferPlanPlant({
    required this.plantCode,
    required this.plantName,
    required this.parts,
    required this.cells,
  });

  bool get isEmpty => parts.isEmpty;
}

/// Fully-aggregated monthly Buffer Creation Plan covering EVERY plant —
/// one [DplBufferPlanPlant] per plant, all sharing the same [days] axis.
class DplBufferPlanWorkbook {
  final int year;
  final int month;

  /// Working days of the month, ascending — idle days (no activity for any
  /// part) are dropped to mirror the customer's working-day layout.
  final List<DateTime> days;

  final List<DplBufferPlanPlant> plants;

  /// Count of (plant, day) input fetches that failed — surfaced so the UI
  /// can warn that some columns may be incomplete.
  final int failedInputCount;

  const DplBufferPlanWorkbook({
    required this.year,
    required this.month,
    required this.days,
    required this.plants,
    this.failedInputCount = 0,
  });

  bool get isEmpty => plants.every((p) => p.isEmpty);

  /// Roll-forward a stock series exactly like the customer's reference sheet:
  /// seed at the first working day that has a stored opening value, then each
  /// subsequent day = previous + [plus] of the previous day − [minus] of the
  /// previous day. All three lists are aligned to the same working-day axis.
  ///   * Opn Stock at TML: plus = Dispatch From GA, minus = Customer Plan
  ///   * Opn Stock at GA : plus = Production at GA, minus = Dispatch From GA
  /// Days before the seed stay null (no basis to compute).
  static List<int?> rollForward({
    required List<int?> seedSeries,
    required List<int?> plus,
    required List<int?> minus,
  }) {
    final n = seedSeries.length;
    final out = List<int?>.filled(n, null);
    for (var p = 0; p < n; p++) {
      if (seedSeries[p] == null) continue;
      out[p] = seedSeries[p];
      for (var q = p + 1; q < n; q++) {
        out[q] = (out[q - 1] ?? 0) + (plus[q - 1] ?? 0) - (minus[q - 1] ?? 0);
      }
      break;
    }
    return out;
  }

  /// Fetches the buffer plan for ALL [plants] in the given [year]/[month]
  /// and aggregates it into a [DplBufferPlanWorkbook].
  ///
  /// Sources (all reachable by the Dispatch role):
  ///   * `GET /manager/dispatch-plan/inputs?plant_code&date` — one call
  ///     per (plant, day): Opn Stock at TML / Production at GA / Customer
  ///     Plan / (Opn Stock at GA) per part, date-accurate.
  ///   * `GET /dispatch/slips?status=dispatched&from&to` — paged ONCE over
  ///     a window WIDER than the month, then bucketed client-side by the
  ///     slip's `dispatchedAt` day. The wide window guards against the
  ///     endpoint filtering `from/to` on `created_at` rather than
  ///     `dispatched_at`, which would otherwise drop slips created before
  ///     the month but dispatched inside it.
  ///
  /// [onProgress] reports `(done, total)` coarse steps for the progress UI.
  static Future<DplBufferPlanWorkbook> fetchAll({
    required DplApiService api,
    required List<DplPlant> plants,
    required int year,
    required int month,
    void Function(int done, int total)? onProgress,
  }) async {
    final lastDay = DateTime(year, month + 1, 0).day;
    final days = <DateTime>[
      for (var d = 1; d <= lastDay; d++) DateTime(year, month, d),
    ];

    // Only fetch inputs for days that have happened — future days carry no
    // snapshot/production data.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fetchDays =
        days.where((d) => !d.isAfter(today)).toList(growable: false);

    final totalSteps = plants.length * fetchDays.length + 1;
    var doneSteps = 0;
    void tick() {
      doneSteps++;
      onProgress?.call(doneSteps, totalSteps);
    }

    // ---- 1. Dispatched slips — one wide pass across ALL plants ----
    // dispByPlant[plantCode][partId] = per-day qty (days.length long).
    final dispByPlant = <String, Map<int, List<int>>>{};
    final dispIdent = <String, Map<int, _Ident>>{};
    final wideFrom =
        DateTime(year, month, 1).subtract(const Duration(days: 31));
    final wideTo = DateTime(year, month, lastDay).add(const Duration(days: 2));
    var page = 1;
    while (page <= 500) {
      final res = await api.listDispatchSlips(
        status: DplDispatchSlipStatus.dispatched,
        from: wideFrom,
        to: wideTo,
        page: page,
        limit: 100,
      );
      if (res.isError || res.data == null) break;
      final pageData = res.data!;
      for (final slip in pageData.items) {
        final at = slip.dispatchedAt?.toLocal();
        if (at == null) continue;
        if (at.year != year || at.month != month) continue; // target month only
        final dayIdx = at.day - 1;
        final pc = slip.plant.code;
        final partMap = dispByPlant.putIfAbsent(pc, () => <int, List<int>>{});
        final identMap = dispIdent.putIfAbsent(pc, () => <int, _Ident>{});
        for (final item in slip.items) {
          final list = partMap.putIfAbsent(
            item.partId,
            () => List<int>.filled(days.length, 0),
          );
          list[dayIdx] += item.qty;
          identMap.putIfAbsent(
            item.partId,
            () => _Ident(item.customerPartNo, item.description, item.partName),
          );
        }
      }
      if (!pageData.hasMore) break;
      page++;
    }
    tick();

    // ---- 2. Per-plant inputs (Opn Stock TML / Production / Customer Plan) ----
    var failedInputCount = 0;
    final plantAccs = <_PlantAcc>[];

    for (final plant in plants) {
      final accByPart = <int, _Acc>{};
      _Acc accFor(int partId) =>
          accByPart.putIfAbsent(partId, () => _Acc(days.length));

      const batchSize = 5;
      for (var i = 0; i < fetchDays.length; i += batchSize) {
        final end = (i + batchSize <= fetchDays.length)
            ? i + batchSize
            : fetchDays.length;
        final batch = fetchDays.sublist(i, end);
        final results = await Future.wait(
          batch.map(
            (d) => api.getDispatchPlanInputs(plantCode: plant.code, date: d),
          ),
        );
        for (var b = 0; b < batch.length; b++) {
          final day = batch[b];
          final dayIdx = day.day - 1;
          final res = results[b];
          tick();
          if (res.isError || res.data == null) {
            failedInputCount++;
            continue;
          }
          for (final row in res.data!.parts) {
            final acc = accFor(row.partId);
            acc.registerIdentity(
              customerPn: row.customerPn,
              description: row.description,
              partName: row.partName,
            );
            acc.tml[dayIdx] = row.tmlOpeningStock;
            acc.ga[dayIdx] = row.gaOpeningStock;
            // Treat 0 production as a blank cell so the sheet stays readable.
            acc.prod[dayIdx] =
                row.gaProductionToday == 0 ? null : row.gaProductionToday;
            acc.plan[dayIdx] = row.customerPlanToday;
          }
        }
      }

      // Merge this plant's dispatched-qty buckets in.
      final partMap = dispByPlant[plant.code];
      final identMap = dispIdent[plant.code];
      if (partMap != null) {
        partMap.forEach((partId, perDay) {
          final acc = accFor(partId);
          final ident = identMap?[partId];
          if (ident != null) {
            acc.registerIdentity(
              customerPn: ident.pn,
              description: ident.desc,
              partName: ident.name,
            );
          }
          for (var i = 0; i < days.length; i++) {
            if (perDay[i] > 0) acc.disp[i] = perDay[i];
          }
        });
      }

      plantAccs.add(_PlantAcc(plant, accByPart));
    }

    // Working-day axis: keep only days where SOME part (any plant) has real
    // input data — production, dispatch, customer plan, or a stored TML
    // opening stock. Drops idle days (e.g. Sundays) so the sheet matches the
    // customer's working-day layout without hard-coding a weekend rule.
    final activeIdx = <int>[];
    for (var di = 0; di < days.length; di++) {
      var has = false;
      outer:
      for (final pa in plantAccs) {
        for (final acc in pa.accByPart.values) {
          if (acc.prod[di] != null ||
              acc.disp[di] != null ||
              acc.plan[di] != null ||
              acc.tml[di] != null) {
            has = true;
            break outer;
          }
        }
      }
      if (has) activeIdx.add(di);
    }
    final activeDays = [for (final di in activeIdx) days[di]];

    final plantSheets = [
      for (final pa in plantAccs) _freeze(pa.plant, pa.accByPart, activeIdx),
    ];

    return DplBufferPlanWorkbook(
      year: year,
      month: month,
      days: activeDays,
      plants: plantSheets,
      failedInputCount: failedInputCount,
    );
  }

  /// Builds one plant sheet over the [activeIdx] working-day columns, with
  /// Opn Stock at TML & GA COMPUTED by roll-forward (see [rollForward]) — the
  /// same formulas the customer's reference sheet uses. Production / Dispatch /
  /// Customer Plan are shown as fetched (blank where the app has no value).
  static DplBufferPlanPlant _freeze(
    DplPlant plant,
    Map<int, _Acc> accByPart,
    List<int> activeIdx,
  ) {
    final parts = accByPart.entries
        .map((e) => DplBufferPlanPart(
              partId: e.key,
              customerPn: e.value.customerPn,
              description: e.value.description,
              partName: e.value.partName,
            ))
        .toList()
      ..sort((a, b) {
        final byPn = a.pnLabel.toLowerCase().compareTo(b.pnLabel.toLowerCase());
        if (byPn != 0) return byPn;
        return a.descLabel.toLowerCase().compareTo(b.descLabel.toLowerCase());
      });

    final n = activeIdx.length;
    final cells = <int, List<DplBufferPlanCell>>{};
    for (final part in parts) {
      final acc = accByPart[part.partId]!;
      // Re-slice each metric onto the working-day axis.
      final tmlSeed = [for (final di in activeIdx) acc.tml[di]];
      final gaSeed = [for (final di in activeIdx) acc.ga[di]];
      final prod = [for (final di in activeIdx) acc.prod[di]];
      final disp = [for (final di in activeIdx) acc.disp[di]];
      final plan = [for (final di in activeIdx) acc.plan[di]];

      final tmlOut = DplBufferPlanWorkbook.rollForward(
        seedSeries: tmlSeed,
        plus: disp,
        minus: plan,
      );
      final gaOut = DplBufferPlanWorkbook.rollForward(
        seedSeries: gaSeed,
        plus: prod,
        minus: disp,
      );

      cells[part.partId] = [
        for (var p = 0; p < n; p++)
          DplBufferPlanCell(
            opnStockTml: tmlOut[p],
            opnStockGa: gaOut[p],
            productionGa: prod[p],
            dispatchGa: disp[p],
            customerPlan: plan[p],
          ),
      ];
    }

    return DplBufferPlanPlant(
      plantCode: plant.code,
      plantName: plant.name,
      parts: parts,
      cells: cells,
    );
  }
}

/// Pairs a plant with its mutable accumulator while [DplBufferPlanWorkbook.fetchAll]
/// is collecting data, before the working-day axis is known.
class _PlantAcc {
  final DplPlant plant;
  final Map<int, _Acc> accByPart;
  const _PlantAcc(this.plant, this.accByPart);
}

/// Tiny identity triple carried from a dispatch-slip item.
class _Ident {
  final String pn;
  final String desc;
  final String name;
  const _Ident(this.pn, this.desc, this.name);
}

/// Mutable per-part accumulator used only inside [DplBufferPlanWorkbook.fetchAll].
class _Acc {
  String customerPn = '';
  String description = '';
  String partName = '';
  final List<int?> tml;
  final List<int?> ga;
  final List<int?> prod;
  final List<int?> disp;
  final List<int?> plan;

  _Acc(int dayCount)
      : tml = List<int?>.filled(dayCount, null),
        ga = List<int?>.filled(dayCount, null),
        prod = List<int?>.filled(dayCount, null),
        disp = List<int?>.filled(dayCount, null),
        plan = List<int?>.filled(dayCount, null);

  /// Fills any blank identity field — first non-empty source wins, but a
  /// later source can backfill a field an earlier one left empty.
  void registerIdentity({
    required String customerPn,
    required String description,
    required String partName,
  }) {
    if (this.customerPn.trim().isEmpty && customerPn.trim().isNotEmpty) {
      this.customerPn = customerPn.trim();
    }
    if (this.description.trim().isEmpty && description.trim().isNotEmpty) {
      this.description = description.trim();
    }
    if (this.partName.trim().isEmpty && partName.trim().isNotEmpty) {
      this.partName = partName.trim();
    }
  }
}

/// Builds the monthly Buffer Creation Plan workbook from a
/// [DplBufferPlanWorkbook] — one worksheet per plant. Each sheet is a
/// day-major matrix with a 5-metric block per day, frozen first two
/// columns + three header rows.
class DplBufferPlanExporter {
  const DplBufferPlanExporter._();

  static const _metricsPerDay = 5;
  static const _metricLabels = <String>[
    'Opn Stock at TML',
    'Opn Stock at GA',
    'Production at GA',
    'Dispatch From GA',
    'Customer Plan',
  ];

  // ARGB hex bands (same format the chart exporter uses).
  static const _bandTitle = 'FF4A1163'; // deep plum — white text
  static const _bandDay = 'FFE9D8F2'; // light purple
  static const _bandMetric = 'FFF3EEF7'; // very light purple
  static const _bandPartHeader = 'FFE9D8F2';
  static const _tintDispatch = 'FFFCEAF4'; // pink wash — highlight column
  static const _white = 'FFFFFFFF';

  static Uint8List build(DplBufferPlanWorkbook wb) {
    final excel = Excel.createExcel();
    final dynamic excelDyn = excel;
    String? defaultName;
    try {
      defaultName = excelDyn.getDefaultSheet() as String?;
    } catch (_) {
      defaultName = null;
    }

    final styles = _Styles();
    final used = <String>{};

    final nonEmpty = wb.plants.where((p) => p.parts.isNotEmpty).toList();

    if (nonEmpty.isEmpty) {
      // Keep the workbook valid with a single explanatory sheet.
      final name = defaultName ?? 'Buffer Plan';
      final sheet = excel[name];
      _put(
        sheet,
        0,
        0,
        'No buffer-plan data for '
        '${DateFormat('MMMM yyyy').format(DateTime(wb.year, wb.month))}.',
        styles.title,
      );
    } else {
      for (final plant in nonEmpty) {
        final name = _safeSheetName(
          plant.plantName.isEmpty ? plant.plantCode : plant.plantName,
          used,
        );
        _buildSheet(excel[name], plant, wb, styles);
      }
      // Drop the auto-created default sheet if it isn't one of ours.
      if (defaultName != null && !used.contains(defaultName.toLowerCase())) {
        try {
          excelDyn.delete(defaultName);
        } catch (_) {}
      }
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Failed to encode the Buffer Creation Plan workbook.');
    }
    // Freeze the two identity columns + three header rows on every sheet.
    // `excel` exposes no freeze API, so we patch each worksheet's XML
    // (same approach as the Monthly Chart export).
    return _injectFreezePane(
      Uint8List.fromList(encoded),
      xSplit: 2,
      ySplit: 3,
    );
  }

  static void _buildSheet(
    Sheet sheet,
    DplBufferPlanPlant plant,
    DplBufferPlanWorkbook wb,
    _Styles styles,
  ) {
    const colPn = 0;
    const colDesc = 1;
    const firstDayCol = 2;
    final days = wb.days;
    final lastCol = firstDayCol + days.length * _metricsPerDay - 1;

    int dayBlockStart(int dayIdx) => firstDayCol + dayIdx * _metricsPerDay;

    // ---- Row 0 — title band across the whole sheet ----
    final title =
        'BUFFER CREATION PLAN   •   ${plant.plantName.isEmpty ? plant.plantCode : plant.plantName}'
        '   •   ${DateFormat('MMMM yyyy').format(DateTime(wb.year, wb.month))}';
    for (var c = colPn; c <= lastCol; c++) {
      _put(sheet, 0, c, c == colPn ? title : '', styles.title);
    }
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: colPn, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: 0),
    );
    sheet.setRowHeight(0, 24);

    // ---- Row 1 — leading labels + per-day date header (merged ×5) ----
    _put(sheet, 1, colPn, 'Customer Part No.', styles.partHeader);
    _put(sheet, 1, colDesc, 'Part Description', styles.partHeader);
    final dayHeaderFmt = DateFormat('dd-MMM EEE');
    for (var i = 0; i < days.length; i++) {
      final start = dayBlockStart(i);
      for (var m = 0; m < _metricsPerDay; m++) {
        _put(
          sheet,
          1,
          start + m,
          m == 0 ? dayHeaderFmt.format(days[i]) : '',
          styles.dayHeader,
        );
      }
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: start, rowIndex: 1),
        CellIndex.indexByColumnRow(
            columnIndex: start + _metricsPerDay - 1, rowIndex: 1),
      );
    }

    // ---- Row 2 — leading labels (merged up) + metric sub-headers ----
    _put(sheet, 2, colPn, '', styles.partHeader);
    _put(sheet, 2, colDesc, '', styles.partHeader);
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: colPn, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: colPn, rowIndex: 2),
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: colDesc, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: colDesc, rowIndex: 2),
    );
    for (var i = 0; i < days.length; i++) {
      final start = dayBlockStart(i);
      for (var m = 0; m < _metricsPerDay; m++) {
        _put(
          sheet,
          2,
          start + m,
          _metricLabels[m],
          m == 3 ? styles.metricHeaderDispatch : styles.metricHeader,
        );
      }
    }
    sheet.setRowHeight(2, 30);

    // ---- Rows 3+ — one row per part ----
    var r = 3;
    for (final part in plant.parts) {
      _put(sheet, r, colPn, part.pnLabel, styles.pnCell);
      _put(sheet, r, colDesc, part.descLabel, styles.descCell);
      final cells = plant.cells[part.partId]!;
      for (var i = 0; i < days.length; i++) {
        final start = dayBlockStart(i);
        final cell = cells[i];
        _putInt(sheet, r, start + 0, cell.opnStockTml, styles.numCell);
        _putInt(sheet, r, start + 1, cell.opnStockGa, styles.numCell);
        _putInt(sheet, r, start + 2, cell.productionGa, styles.numCell);
        _putInt(sheet, r, start + 3, cell.dispatchGa, styles.numCellDispatch);
        _putInt(sheet, r, start + 4, cell.customerPlan, styles.numCell);
      }
      r++;
    }

    // ---- Column widths ----
    sheet.setColumnWidth(colPn, 20);
    sheet.setColumnWidth(colDesc, 22);
    for (var i = 0; i < days.length; i++) {
      final start = dayBlockStart(i);
      for (var m = 0; m < _metricsPerDay; m++) {
        sheet.setColumnWidth(start + m, 9);
      }
    }
  }

  /// Excel-safe, unique sheet name (≤31 chars, no `: \ / ? * [ ]`).
  static String _safeSheetName(String raw, Set<String> used) {
    var s = raw.replaceAll(RegExp(r'[\\/\?\*\[\]:]'), ' ').trim();
    if (s.isEmpty) s = 'Plant';
    if (s.length > 28) s = s.substring(0, 28);
    var name = s;
    var n = 2;
    while (used.contains(name.toLowerCase())) {
      final stem = s.length > 26 ? s.substring(0, 26) : s;
      name = '$stem $n';
      n++;
    }
    used.add(name.toLowerCase());
    return name;
  }

  // ===== cell helpers =====

  static void _put(Sheet sheet, int row, int col, String value, CellStyle s) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = s;
  }

  /// Writes an int, or a styled-but-empty cell when [value] is null so the
  /// matrix keeps its gridlines without printing a misleading 0. We write
  /// an empty `TextCellValue` (not `null`) because the `excel` package
  /// drops styling — including borders — for null-valued cells, which would
  /// punch holes in the grid.
  static void _putInt(Sheet sheet, int row, int col, int? value, CellStyle s) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value == null ? TextCellValue('') : IntCellValue(value);
    cell.cellStyle = s;
  }

  /// 0 → A, 25 → Z, 26 → AA … — used to build the freeze-pane topLeftCell.
  static String _col(int index) {
    var n = index;
    final out = StringBuffer();
    while (true) {
      final rem = n % 26;
      out.write(String.fromCharCode(65 + rem));
      n = (n ~/ 26) - 1;
      if (n < 0) break;
    }
    return out.toString().split('').reversed.join();
  }

  static Uint8List _injectFreezePane(
    Uint8List bytes, {
    required int xSplit,
    required int ySplit,
  }) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final patched = <ArchiveFile>[];
      for (final file in archive.files) {
        if (file.name.startsWith('xl/worksheets/sheet') &&
            file.name.endsWith('.xml')) {
          final raw = file.content;
          final xml = raw is List<int> ? utf8.decode(raw) : raw.toString();
          final encoded = utf8.encode(_patchSheetViewXml(xml, xSplit, ySplit));
          patched.add(ArchiveFile(file.name, encoded.length, encoded));
        } else {
          patched.add(file);
        }
      }
      final newArchive = Archive();
      for (final f in patched) {
        newArchive.addFile(f);
      }
      final reencoded = ZipEncoder().encode(newArchive);
      if (reencoded == null) return bytes;
      return Uint8List.fromList(reencoded);
    } catch (_) {
      return bytes;
    }
  }

  static String _patchSheetViewXml(String xml, int xSplit, int ySplit) {
    final topLeft = '${_col(xSplit)}${ySplit + 1}';
    final paneXml =
        '<pane xSplit="$xSplit" ySplit="$ySplit" topLeftCell="$topLeft" activePane="bottomRight" state="frozen"/>';

    final selfClose = RegExp(r'<sheetView\b[^/>]*\/>');
    final mA = selfClose.firstMatch(xml);
    if (mA != null) {
      final tag = mA.group(0)!;
      final opened = tag.replaceFirst('/>', '>');
      return xml.replaceFirst(tag, '$opened$paneXml</sheetView>');
    }

    final openTag = RegExp(r'<sheetView\b[^>]*>');
    final mB = openTag.firstMatch(xml);
    if (mB != null) {
      return xml.replaceFirst(mB.group(0)!, '${mB.group(0)!}$paneXml');
    }

    final wsOpen = RegExp(r'<worksheet\b[^>]*>');
    final mC = wsOpen.firstMatch(xml);
    if (mC != null) {
      final injected =
          '<sheetViews><sheetView workbookViewId="0">$paneXml</sheetView></sheetViews>';
      return xml.replaceFirst(mC.group(0)!, '${mC.group(0)!}$injected');
    }
    return xml;
  }
}

/// Pre-built [CellStyle]s for the Buffer Creation Plan, kept out of the
/// builder so the layout code stays readable. Mirrors the chart exporter's
/// `_Styles` approach (thin black borders + ARGB bands + Aptos Narrow).
class _Styles {
  static Border get _thin =>
      Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);

  static CellStyle _base({
    required String bgHex,
    String? fgHex,
    bool bold = false,
    int fontSize = dplExcelFontSize,
    HorizontalAlign h = HorizontalAlign.Center,
    TextWrapping? wrap,
  }) {
    return CellStyle(
      backgroundColorHex: ExcelColor.fromHexString(bgHex),
      fontColorHex:
          fgHex == null ? ExcelColor.black : ExcelColor.fromHexString(fgHex),
      bold: bold,
      fontSize: fontSize,
      fontFamily: dplExcelFontFamily,
      horizontalAlign: h,
      verticalAlign: VerticalAlign.Center,
      textWrapping: wrap,
      leftBorder: _thin,
      rightBorder: _thin,
      topBorder: _thin,
      bottomBorder: _thin,
      numberFormat: NumFormat.standard_0,
    );
  }

  late final CellStyle title = _base(
    bgHex: DplBufferPlanExporter._bandTitle,
    fgHex: DplBufferPlanExporter._white,
    bold: true,
    fontSize: 13,
  );

  late final CellStyle partHeader = _base(
    bgHex: DplBufferPlanExporter._bandPartHeader,
    bold: true,
    fontSize: 11,
    h: HorizontalAlign.Left,
    wrap: TextWrapping.WrapText,
  );

  late final CellStyle dayHeader = _base(
    bgHex: DplBufferPlanExporter._bandDay,
    bold: true,
    fontSize: 11,
  );

  late final CellStyle metricHeader = _base(
    bgHex: DplBufferPlanExporter._bandMetric,
    bold: true,
    fontSize: 8,
    wrap: TextWrapping.WrapText,
  );

  late final CellStyle metricHeaderDispatch = _base(
    bgHex: DplBufferPlanExporter._tintDispatch,
    bold: true,
    fontSize: 8,
    wrap: TextWrapping.WrapText,
  );

  late final CellStyle pnCell = _base(
    bgHex: DplBufferPlanExporter._white,
    bold: true,
    h: HorizontalAlign.Left,
  );

  late final CellStyle descCell = _base(
    bgHex: DplBufferPlanExporter._white,
    h: HorizontalAlign.Left,
  );

  late final CellStyle numCell = _base(bgHex: DplBufferPlanExporter._white);

  late final CellStyle numCellDispatch =
      _base(bgHex: DplBufferPlanExporter._tintDispatch);
}
