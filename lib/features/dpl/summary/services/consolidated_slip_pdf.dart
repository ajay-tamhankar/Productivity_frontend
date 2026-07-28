import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/dpl_consolidated_slip.dart';

/// Print-ready **consolidated trip slip** — the whole trip rendered in the
/// exact Vistar Pulse dispatch-slip format (gradient header band, plate
/// identity strip, "SCAN TO VERIFY" QR sidebar, `# / PART DESCRIPTION /
/// CUSTOMER P/N / QUANTITY` table, TOTAL DISPATCHED row) but with EVERY
/// slip on the trip flattened into the one parts table. Single A4-landscape
/// page; the parts rows step down in density as the line-item count grows
/// so a full trip still lands on one page.
///
/// This is the print twin of the on-screen consolidated slip, and it
/// mirrors [DispatchSlipPdfBuilder]'s styling 1:1 so the single-slip and
/// consolidated documents read as one system.
class ConsolidatedSlipPdfBuilder {
  const ConsolidatedSlipPdfBuilder._();

  // ── Palette — lifted verbatim from the dispatch-slip PDF. ──
  static const _brand = PdfColor.fromInt(0xFFA3238E);
  static const _ink = PdfColor.fromInt(0xFF1A161D);
  static const _muted = PdfColor.fromInt(0xFF78727F);
  static const _faint = PdfColor.fromInt(0xFF1A161D);
  static const _line = PdfColor.fromInt(0xFFE9E6EC);
  static const _lineSoft = PdfColor.fromInt(0xFFF1EFF3);
  static const _surface = PdfColor.fromInt(0xFFFAF9FB);

  static const _bandDark = PdfColor.fromInt(0xFF2A0A36);
  static const _bandMid = PdfColor.fromInt(0xFF4A1163);
  static const _bandLight = PdfColor.fromInt(0xFF6B1F8C);
  static const _bandChipBg = PdfColor.fromInt(0xFFB958AB);
  static const _bandChipBorder = PdfColor.fromInt(0xFFCC8AC4);

  static const _trustText = PdfColor.fromInt(0xFF4F7A64);

  static Future<Uint8List> build(
    DplConsolidatedSlip data, {
    String? organizationLabel,
  }) async {
    final fonts = await _Fonts.load();
    final trip = data.trip;

    final doc = pw.Document(
      title: 'Consolidated Slip · Trip ${trip.tripNumber}',
      author: 'Grupo Antolin India Private Limited',
      theme: pw.ThemeData.withFont(base: fonts.uiRegular, bold: fonts.uiBold),
    );

    doc.addPage(_page(data, fonts, organizationLabel));
    return doc.save();
  }

  // One A4-LANDSCAPE page rendering the whole trip. Not MultiPage: the QR
  // sidebar + parts table form one side-by-side body, so instead of
  // paginating we step the parts-row density down as the line-item count
  // grows (see `_Density.forCount`) so a full trip still fits one page.
  static pw.Page _page(
    DplConsolidatedSlip data,
    _Fonts fonts,
    String? org,
  ) {
    final rows = data.flattenRows();
    final fmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('HH:mm');
    final density = _Density.forCount(rows.length);

    return pw.Page(
      // Portrait, not landscape: a consolidated trip carries many line items,
      // and portrait's taller body fits ~20 two-line rows on ONE page vs
      // landscape's ~12 (which would clip a multi-slip trip). Same dispatch-
      // slip design either way; the rows also step down in density as the
      // count grows so a full trip still lands on one page.
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(16, 16, 16, 16),
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: _line),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            _band(data, fonts, org),
            _identity(data, rows, fonts, dateFmt, timeFmt),
            _bodyRow(data, rows, fonts, fmt, density),
          ],
        ),
      ),
    );
  }

  // ── Header band — gradient purple, GA mark + company on the left,
  //    "DISPATCH SLIP" + Trip chip on the right. ──
  static pw.Widget _band(DplConsolidatedSlip data, _Fonts fonts, String? org) {
    final slipCount = data.slips.length;
    return pw.Container(
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_bandDark, _bandMid, _bandLight],
          stops: [0.0, 0.5, 1.0],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
      ),
      padding: const pw.EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 40,
                  height: 32,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: _bandChipBg,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: _bandChipBorder),
                  ),
                  child: pw.Text(
                    'GA',
                    maxLines: 1,
                    style: pw.TextStyle(
                      font: fonts.uiBold,
                      fontSize: 18,
                      color: PdfColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                // Expanded + maxLines:2 so the company name wraps within its
                // own column instead of running under the DISPATCH SLIP title
                // at the narrower portrait width.
                pw.Expanded(
                  child: pw.Text(
                    'Grupo Antolin India Private Limited',
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                    style: pw.TextStyle(
                      font: fonts.uiBold,
                      fontSize: 14,
                      color: PdfColors.white,
                      letterSpacing: 0.4,
                      lineSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'DISPATCH SLIP',
                style: pw.TextStyle(
                  font: fonts.uiBold,
                  fontSize: 16,
                  color: PdfColors.white,
                  letterSpacing: 1.8,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: _bandChipBg,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(7)),
                  border: pw.Border.all(color: _bandChipBorder),
                ),
                child: pw.Text(
                  'Trip #${data.trip.tripNumber}  ·  $slipCount '
                  'slip${slipCount == 1 ? '' : 's'}'
                  '${org != null && org.trim().isNotEmpty ? '  ·  ${org.trim()}' : ''}',
                  style: pw.TextStyle(
                    font: fonts.uiBold,
                    fontSize: 11,
                    color: PdfColors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Identity strip — VEHICLE plate + PLANT + MACHINE + PART DESCRIPTION
  //    + DISPATCHED, trip-consolidated. ──
  static pw.Widget _identity(
    DplConsolidatedSlip data,
    List<DplConsolidatedSlipRow> rows,
    _Fonts fonts,
    DateFormat dateFmt,
    DateFormat timeFmt,
  ) {
    final trip = data.trip;

    // Machine headline: the one machine when the whole trip shares it,
    // else the machine count (the per-line machines are in the table).
    final machines = rows
        .map((r) => r.machineLabel.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final machineLabel = machines.length <= 1
        ? (machines.isEmpty ? '-' : machines.first)
        : '${machines.length} machines';

    // Part headline: first line's description code + "+ N more".
    final firstPart = rows.isEmpty
        ? '-'
        : (rows.first.description.trim().isNotEmpty
            ? rows.first.description.trim()
            : rows.first.partLabel);
    final partSub = rows.length > 1 ? '+ ${rows.length - 1} more' : null;

    // Dispatched: the most recent slip dispatch across the trip.
    DateTime? disp;
    for (final s in data.slips) {
      final at = s.dispatchedAt;
      if (at != null && (disp == null || at.isAfter(disp))) disp = at;
    }
    final dateStr = disp == null ? '-' : dateFmt.format(disp.toLocal());
    final timeStr = disp == null ? null : '${timeFmt.format(disp.toLocal())} IST';

    final plant = trip.plantName.isNotEmpty ? trip.plantName : trip.plantCode;

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 14,
            child: _idCell(
              background: _surface,
              leftBorder: false,
              child: _plateCell(fonts, data.vehicleNo.trim()),
            ),
          ),
          pw.Expanded(
            flex: 10,
            child: _idCell(child: _labelValue(fonts, 'PLANT', plant)),
          ),
          pw.Expanded(
            flex: 10,
            child: _idCell(child: _labelValue(fonts, 'MACHINE', machineLabel)),
          ),
          pw.Expanded(
            flex: 10,
            child: _idCell(
              child: _platePartCell(fonts, firstPart, partSub),
            ),
          ),
          pw.Expanded(
            flex: 11,
            child: _idCell(
              child: _labelValue(fonts, 'DISPATCHED', dateStr,
                  subValue: timeStr),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _idCell({
    required pw.Widget child,
    PdfColor background = PdfColors.white,
    bool leftBorder = true,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: pw.BoxDecoration(
        color: background,
        border: pw.Border(
          left: leftBorder
              ? const pw.BorderSide(color: _lineSoft)
              : pw.BorderSide.none,
        ),
      ),
      child: child,
    );
  }

  static pw.Widget _labelValue(
    _Fonts fonts,
    String label,
    String value, {
    String? subValue,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: fonts.uiBold,
            fontSize: 9,
            color: _faint,
            letterSpacing: 0.4,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fonts.uiBold,
            fontSize: 22,
            color: _ink,
            letterSpacing: 0.8,
          ),
          maxLines: 2,
          overflow: pw.TextOverflow.clip,
        ),
        if (subValue != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            subValue,
            style: pw.TextStyle(
              font: fonts.uiBold,
              fontSize: 13,
              color: _muted,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _plateCell(_Fonts fonts, String vehicle) {
    final plate = vehicle.isEmpty ? '-' : vehicle;
    final n = plate.length;
    final double size;
    final double spacing;
    if (n <= 8) {
      size = 30;
      spacing = 1.2;
    } else if (n <= 10) {
      size = 26;
      spacing = 0.8;
    } else if (n <= 12) {
      size = 22;
      spacing = 0.6;
    } else {
      size = 18;
      spacing = 0.4;
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          'VEHICLE',
          style: pw.TextStyle(
            font: fonts.uiBold,
            fontSize: 9,
            color: _faint,
            letterSpacing: 0.4,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            plate,
            style: pw.TextStyle(
              font: fonts.uiBold,
              fontSize: size,
              color: _ink,
              letterSpacing: spacing,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    );
  }

  static pw.Widget _platePartCell(
    _Fonts fonts,
    String code,
    String? subValue,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          'PART DESCRIPTION',
          style: pw.TextStyle(
            font: fonts.uiBold,
            fontSize: 9,
            color: _faint,
            letterSpacing: 0.4,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            code,
            style: pw.TextStyle(
              font: fonts.uiBold,
              fontSize: 30,
              color: _ink,
              letterSpacing: 1.2,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
        if (subValue != null) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            subValue,
            style: pw.TextStyle(
              font: fonts.uiBold,
              fontSize: 12,
              color: _muted,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }

  // ── Two-column body — QR sidebar (left) + parts table & total (right).
  //    A pw.Table gives the QR cell a bounded, fixed width so the barcode
  //    always measures, regardless of how many parts the trip carries. ──
  static pw.Widget _bodyRow(
    DplConsolidatedSlip data,
    List<DplConsolidatedSlipRow> rows,
    _Fonts fonts,
    NumberFormat fmt,
    _Density d,
  ) {
    return pw.Table(
      // `full` stretches the QR sidebar cell to the full height of the parts
      // column so its surface panel + right divider span the whole body
      // (no half-height grey block when the parts table is taller).
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
      columnWidths: const {
        0: pw.FixedColumnWidth(190),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            _verifySidebar(data, fonts),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                _parts(rows, fonts, fmt, d),
                _totalRow(data, rows.length, fonts, fmt),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _verifySidebar(DplConsolidatedSlip data, _Fonts fonts) {
    final hasQr = data.qrToken.isNotEmpty;
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: _surface,
        border: pw.Border(right: pw.BorderSide(color: _line)),
      ),
      padding: const pw.EdgeInsets.fromLTRB(14, 18, 14, 18),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'SCAN TO VERIFY',
            style: pw.TextStyle(
              font: fonts.uiBold,
              fontSize: 11,
              color: _faint,
              letterSpacing: 1.5,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: 160,
            height: 160,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              border: pw.Border.all(color: _line),
            ),
            child: hasQr
                ? pw.SizedBox(
                    width: 144,
                    height: 144,
                    child: pw.BarcodeWidget(
                      width: 144,
                      height: 144,
                      barcode: pw.Barcode.qrCode(
                        errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
                      ),
                      data: data.qrToken,
                      color: _ink,
                      drawText: false,
                    ),
                  )
                : pw.Center(
                    child: pw.Text(
                      'QR not\navailable',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fonts.uiBold,
                        fontSize: 11,
                        color: _muted,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Scan at Origin Gate (Security) and TATA Dock (QRE)  ·  '
            'HMAC-signed',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: fonts.uiBold,
              fontSize: 10,
              color: _trustText,
            ),
          ),
        ],
      ),
    );
  }

  // ── Parts table — header + one row per (slip, item) across the trip. ──
  static pw.Widget _parts(
    List<DplConsolidatedSlipRow> rows,
    _Fonts fonts,
    NumberFormat fmt,
    _Density d,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _partsHeader(fonts),
        for (var i = 0; i < rows.length; i++)
          _partRow(
            fonts: fonts,
            fmt: fmt,
            d: d,
            index: i + 1,
            row: rows[i],
            firstOfSlip: i == 0 || rows[i].slipId != rows[i - 1].slipId,
            isLast: i == rows.length - 1,
          ),
      ],
    );
  }

  static pw.Widget _partsHeader(_Fonts fonts) {
    final style = pw.TextStyle(
      font: fonts.uiBold,
      fontSize: 11,
      color: _faint,
      letterSpacing: 1.2,
    );
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: _surface,
        border: pw.Border(bottom: pw.BorderSide(color: _line)),
      ),
      padding: const pw.EdgeInsets.fromLTRB(16, 9, 16, 9),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 32,
            child: pw.Text('#', textAlign: pw.TextAlign.center, style: style),
          ),
          pw.Expanded(
            flex: 11,
            child: pw.Text('PART DESCRIPTION', style: style),
          ),
          pw.Expanded(flex: 7, child: pw.Text('CUSTOMER P/N', style: style)),
          pw.SizedBox(
            width: 96,
            child: pw.Text('QUANTITY',
                textAlign: pw.TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }

  static pw.Widget _partRow({
    required _Fonts fonts,
    required NumberFormat fmt,
    required _Density d,
    required int index,
    required DplConsolidatedSlipRow row,
    required bool firstOfSlip,
    required bool isLast,
  }) {
    final idxStr = index.toString().padLeft(2, '0');
    final partName = row.partName.trim().isNotEmpty
        ? row.partName.trim()
        : (row.description.trim().isNotEmpty
            ? row.description.trim()
            : row.partLabel);
    final hasSub = row.description.trim().isNotEmpty &&
        row.description.trim() != partName.trim();

    return pw.Container(
      padding: pw.EdgeInsets.fromLTRB(16, d.rowPad, 16, d.rowPad),
      decoration: pw.BoxDecoration(
        color: firstOfSlip ? PdfColors.white : _surface,
        border: pw.Border(
          bottom: pw.BorderSide(color: isLast ? _line : _lineSoft),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 32,
            child: pw.Text(
              idxStr,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: fonts.monoMedium,
                fontSize: d.idx,
                color: _muted,
              ),
            ),
          ),
          pw.Expanded(
            flex: 11,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  partName,
                  style: pw.TextStyle(
                    font: fonts.uiBold,
                    fontSize: d.part,
                    color: _ink,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                ),
                if (hasSub) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    row.description.trim(),
                    style: pw.TextStyle(
                      font: fonts.uiBold,
                      fontSize: d.sub,
                      color: _brand,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                ],
              ],
            ),
          ),
          pw.Expanded(
            flex: 7,
            child: pw.Text(
              row.customerPartNo.trim().isEmpty ? '-' : row.customerPartNo.trim(),
              style: pw.TextStyle(
                font: fonts.uiBold,
                fontSize: d.pn,
                color: _ink,
                letterSpacing: 0.4,
              ),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
          pw.SizedBox(
            width: 96,
            child: pw.RichText(
              textAlign: pw.TextAlign.right,
              text: pw.TextSpan(
                style: pw.TextStyle(
                  font: fonts.uiBold,
                  fontSize: d.qty,
                  color: _ink,
                  letterSpacing: 0.6,
                ),
                children: [
                  pw.TextSpan(text: fmt.format(row.qty)),
                  pw.TextSpan(
                    text: '  NOS',
                    style: pw.TextStyle(
                      font: fonts.uiBold,
                      fontSize: d.qty * 0.55,
                      color: _muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TOTAL DISPATCHED row. ──
  static pw.Widget _totalRow(
    DplConsolidatedSlip data,
    int lineCount,
    _Fonts fonts,
    NumberFormat fmt,
  ) {
    final slipCount = data.slips.length;
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: _surface,
        border: pw.Border(top: pw.BorderSide(color: _ink, width: 1.4)),
      ),
      padding: const pw.EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(width: 32),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'TOTAL DISPATCHED',
                  style: pw.TextStyle(
                    font: fonts.displayBold,
                    fontSize: 15.5,
                    color: _ink,
                    letterSpacing: 1.8,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '$slipCount slip${slipCount == 1 ? '' : 's'}  ·  '
                  '$lineCount line item${lineCount == 1 ? '' : 's'}  ·  '
                  'all quantities verified at loading',
                  style: pw.TextStyle(
                    font: fonts.uiSemiBold,
                    fontSize: 10,
                    color: _muted,
                    letterSpacing: 0.18,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(
            width: 96,
            child: pw.RichText(
              textAlign: pw.TextAlign.right,
              text: pw.TextSpan(
                style: pw.TextStyle(
                  font: fonts.displayBold,
                  fontSize: 23,
                  color: _brand,
                ),
                children: [
                  pw.TextSpan(text: fmt.format(data.totalQty)),
                  pw.TextSpan(
                    text: '  NOS',
                    style: pw.TextStyle(
                      font: fonts.uiBold,
                      fontSize: 11,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-line-item density tiers — the more items a trip carries, the tighter
/// the parts rows, so a full trip still fits a single landscape page.
class _Density {
  final double rowPad;
  final double idx;
  final double part;
  final double sub;
  final double pn;
  final double qty;
  const _Density({
    required this.rowPad,
    required this.idx,
    required this.part,
    required this.sub,
    required this.pn,
    required this.qty,
  });

  // Tiers are monotonic and each is sized to actually FIT its max count in
  // the ~560pt of portrait body left for rows, so a full trip never clips
  // (rows just get denser). Realistic trips (≤~15 items) land in the roomy
  // top tiers; only an unrealistically huge trip (30+ line items) reaches
  // the tightest tier, and even that fits.
  static _Density forCount(int n) {
    if (n <= 8) {
      return const _Density(rowPad: 6, idx: 12, part: 15, sub: 11, pn: 13, qty: 18);
    }
    if (n <= 12) {
      return const _Density(rowPad: 4, idx: 11, part: 13, sub: 10, pn: 12, qty: 16);
    }
    if (n <= 16) {
      return const _Density(rowPad: 2.5, idx: 10, part: 11, sub: 8.5, pn: 11, qty: 14);
    }
    if (n <= 22) {
      return const _Density(rowPad: 1.5, idx: 9, part: 10, sub: 7.5, pn: 10, qty: 13);
    }
    return const _Density(rowPad: 1, idx: 8, part: 8.5, sub: 6.5, pn: 8.5, qty: 11);
  }
}

/// Fonts — Inter (UI), Saira Condensed (the TOTAL display), JetBrains Mono
/// (line index). Falls back to Helvetica / Courier when the Google Fonts
/// CDN is unreachable so the PDF still renders.
class _Fonts {
  final pw.Font displayBold;
  final pw.Font uiRegular;
  final pw.Font uiSemiBold;
  final pw.Font uiBold;
  final pw.Font monoMedium;

  const _Fonts({
    required this.displayBold,
    required this.uiRegular,
    required this.uiSemiBold,
    required this.uiBold,
    required this.monoMedium,
  });

  static Future<_Fonts> load() async {
    try {
      final r = await Future.wait([
        PdfGoogleFonts.sairaCondensedBold(),
        PdfGoogleFonts.interRegular(),
        PdfGoogleFonts.interSemiBold(),
        PdfGoogleFonts.interBold(),
        PdfGoogleFonts.jetBrainsMonoMedium(),
      ]);
      return _Fonts(
        displayBold: r[0],
        uiRegular: r[1],
        uiSemiBold: r[2],
        uiBold: r[3],
        monoMedium: r[4],
      );
    } catch (_) {
      final reg = pw.Font.helvetica();
      final bold = pw.Font.helveticaBold();
      return _Fonts(
        displayBold: bold,
        uiRegular: reg,
        uiSemiBold: bold,
        uiBold: bold,
        monoMedium: pw.Font.courier(),
      );
    }
  }
}
