import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/dpl_dispatch_slip.dart';

/// Builds a print-ready PDF that mirrors the Vistar Pulse slip on-screen
/// view 1:1 — the same gradient purple header band, identity strip,
/// parts table, QA/PDI sign-off checkpoints, QR verification panel, and
/// footer. The HTML reference lives at
/// `vistar_pulse_dispatch_slip.html` and the on-screen widgets live in
/// `dispatch_slip_detail_screen.dart`; this file is the PDF twin of
/// those so download = view = print.
class DispatchSlipPdfBuilder {
  const DispatchSlipPdfBuilder._();

  // ── Palette — lifted verbatim from the HTML / on-screen palette ──
  static const _brand = PdfColor.fromInt(0xFFA3238E);
  static const _ink = PdfColor.fromInt(0xFF1A161D);
  static const _muted = PdfColor.fromInt(0xFF78727F);
  static const _faint = PdfColor.fromInt(0xFF1A161D);
  static const _line = PdfColor.fromInt(0xFFE9E6EC);
  static const _lineSoft = PdfColor.fromInt(0xFFF1EFF3);
  static const _surface = PdfColor.fromInt(0xFFFAF9FB);

  static const _amberInk = PdfColor.fromInt(0xFF9A5B00);
  static const _amberBg = PdfColor.fromInt(0xFFFEF4E0);
  static const _amberLine = PdfColor.fromInt(0xFFF2D49A);

  static const _emeraldInk = PdfColor.fromInt(0xFF0A7A52);
  static const _emeraldBg = PdfColor.fromInt(0xFFE6F6EE);
  static const _emeraldLine = PdfColor.fromInt(0xFFAEE3CA);

  static const _rejectedInk = PdfColor.fromInt(0xFFB91C1C);
  static const _rejectedBg = PdfColor.fromInt(0xFFFEF2F2);
  static const _rejectedLine = PdfColor.fromInt(0xFFFECACA);

  static const _trustText = PdfColor.fromInt(0xFF4F7A64);
  static const _footId = PdfColor.fromInt(0xFF4F4A57);

  // Darker band gradient — operator asked for a heavier header so the
  // white text reads clearly even after print rasterisation. Goes from
  // near-black plum on the left through a deep purple to the existing
  // brand purple on the right.
  static const _bandDark = PdfColor.fromInt(0xFF2A0A36);
  static const _bandMid = PdfColor.fromInt(0xFF4A1163);
  static const _bandLight = PdfColor.fromInt(0xFF6B1F8C);

  // Pre-blended overlay colors for the header band — solid (no alpha)
  // so they always render in print previews / printers that drop alpha
  // channels.
  static const _bandChipBg = PdfColor.fromInt(0xFFB958AB);
  static const _bandChipBorder = PdfColor.fromInt(0xFFCC8AC4);
  static const _bandTextSoft = PdfColor.fromInt(0xFFF1DDEC);

  // Inline SVG icons — pulled from the HTML reference. Keeps the PDF
  // free of icon-font dependencies and renders crisply at any DPI.
  static const _tickSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M9 11l3 3L22 4"/>
  <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/>
</svg>
''';

  // Activity-strip icons — one per timeline entry kind. Same inline-SVG
  // approach as `_tickSvg` so the activity row stays font-free and crisp
  // at any DPI. `currentColor` is swapped for the entry's ink at build.
  static const _sendSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M22 2 11 13"/>
  <path d="M22 2 15 22 11 13 2 9z"/>
</svg>
''';
  static const _checkCircleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
  <path d="M22 4 12 14.01 9 11.01"/>
</svg>
''';
  static const _truckSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M14 18V6a1 1 0 0 0-1-1H3a1 1 0 0 0-1 1v11a1 1 0 0 0 1 1h2"/>
  <path d="M14 9h4l4 4v4a1 1 0 0 1-1 1h-1"/>
  <circle cx="7.5" cy="18.5" r="2.5"/>
  <circle cx="17.5" cy="18.5" r="2.5"/>
</svg>
''';
  static const _xCircleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="10"/>
  <path d="m15 9-6 6"/>
  <path d="m9 9 6 6"/>
</svg>
''';

  // Soft purple tint for the activity badge background — pre-blended
  // (no alpha) so it survives print rasterisation, matching the on-screen
  // `DplColors.primaryTint`.
  static const _brandTint = PdfColor.fromInt(0xFFF6E9F3);

  static Future<Uint8List> build(
    DplDispatchSlip slip, {
    String? organizationLabel,
  }) async {
    final fonts = await _SlipFonts.load();

    final doc = pw.Document(
      title: 'Dispatch Slip ${slip.slipNo}',
      author: 'Grupo Antolin India Private Limited',
      theme: pw.ThemeData.withFont(base: fonts.uiRegular, bold: fonts.uiBold),
    );

    doc.addPage(_buildSlipPage(slip, fonts));

    return doc.save();
  }

  /// Multi-slip print — one PDF, one A4-landscape page per slip. Used
  /// by the Trip Slips screen "Print all" action so a trip's whole
  /// stack lands as a single document at the print sheet. Order of
  /// [slips] is preserved; an empty list produces an empty document
  /// (printing layer surfaces the no-pages error to the caller).
  static Future<Uint8List> buildBatch(
    List<DplDispatchSlip> slips, {
    String? organizationLabel,
  }) async {
    final fonts = await _SlipFonts.load();

    final firstNo = slips.isNotEmpty ? slips.first.slipNo : 'batch';
    final lastNo = slips.length > 1 ? slips.last.slipNo : '';
    final title = slips.length == 1
        ? 'Dispatch Slip $firstNo'
        : 'Dispatch Slips · $firstNo … $lastNo (${slips.length})';

    final doc = pw.Document(
      title: title,
      author: 'Grupo Antolin India Private Limited',
      theme: pw.ThemeData.withFont(base: fonts.uiRegular, bold: fonts.uiBold),
    );

    for (final slip in slips) {
      doc.addPage(_buildSlipPage(slip, fonts));
    }

    return doc.save();
  }

  // One A4-landscape page rendering a single dispatch slip. Shared by
  // both [build] (single-slip print) and [buildBatch] (trip-level
  // print) so the printed surface stays identical regardless of the
  // entry point.
  //
  // We avoid `pw.MultiPage` because the slip is rendered as one
  // rounded-bordered container that can't be split between pages —
  // MultiPage would throw `TooManyPagesException` trying to paginate
  // it. `orientation: landscape` is set explicitly so the browser's
  // print preview always rotates to landscape; relying on
  // `PdfPageFormat.a4.landscape` alone has been flaky across some
  // print sheets (Chrome on Windows shows the page in portrait if
  // the orientation header isn't present).
  static pw.Page _buildSlipPage(DplDispatchSlip slip, _SlipFonts fonts) {
    final fmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('HH:mm');
    final signDateFmt = DateFormat('dd MMM · HH:mm');
    // Full date+time for the Activity strip — mirrors the on-screen
    // `_Timeline` format (`dd MMM yyyy, HH:mm`) shown on the detail screen.
    final activityFmt = DateFormat('dd MMM yyyy, HH:mm');

    final referenceTime =
        slip.pdiApproval?.at ?? slip.qaApproval?.at ?? slip.requestedAt;

    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      orientation: pw.PageOrientation.landscape,
      margin: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
      // Natural content height. We tried wrapping the body in
      // Expanded + pw.Spacer() to claim the whole page, but pdf's
      // Flex layout can't bound the height through a Table cell —
      // it threw "Flex children have non-zero flex but incoming
      // height constraints are unbounded" at print time. So we
      // accept some bottom whitespace on short slips and let the
      // content size itself.
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
            _band(slip, fonts),
            _identity(slip, fonts, dateFmt, timeFmt, referenceTime),
            _bodyRow(slip, fonts, fmt, signDateFmt),
            _activity(slip, fonts, activityFmt),
            _foot(slip, fonts),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Header band — gradient purple, brand mark + wordmark on the left,
  // doc title + slip-no chip on the right.
  // ───────────────────────────────────────────────────────────────────
  static pw.Widget _band(DplDispatchSlip slip, _SlipFonts fonts) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        // Darker gradient — near-black plum on the left, deep brand
        // purple on the right. Heavier than the original tri-stop
        // gradient so white text + the chip read cleanly even after
        // print rasterisation.
        gradient: pw.LinearGradient(
          colors: [_bandDark, _bandMid, _bandLight],
          stops: [0.0, 0.5, 1.0],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
      ),
      padding: const pw.EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(child: _brandBlock(fonts)),
          pw.SizedBox(width: 20),
          _docBlock(slip, fonts),
        ],
      ),
    );
  }

  static pw.Widget _brandBlock(_SlipFonts fonts) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 44,
          height: 36,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            // Solid (pre-blended) colors instead of alpha-over-white —
            // some print sheets drop alpha when rasterising the
            // preview, which made the band look flat grey.
            color: _bandChipBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: _bandChipBorder),
          ),
          child: pw.Text(
            'GA',
            // Single-line — without this, the 22pt bold "GA" + 1.0
            // letter-spacing wrapped each character onto its own
            // line inside the original 32x32 box.
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              // Plate-style — Inter Bold + 0.5 letter-spacing, just
              // in white over the dark band.
              font: fonts.uiBold,
              fontSize: 22,
              color: PdfColors.white,
              letterSpacing: 0.5,
              lineSpacing: 0,
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              'Grupo Antolin India Private Limited',
              style: pw.TextStyle(
                font: fonts.uiBold,
                fontSize: 22,
                color: PdfColors.white,
                letterSpacing: 1.0,
              ),
            ),
            pw.SizedBox(height: 3),
            // pw.Text(
            //   'DISPATCH SLIP',
            //   style: pw.TextStyle(
            //     font: fonts.uiBold,
            //     fontSize: 8.5,
            //     color: _bandTextSoft,
            //     letterSpacing: 2.0,
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _docBlock(DplDispatchSlip slip, _SlipFonts fonts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          'DISPATCH SLIP',
          style: pw.TextStyle(
            font: fonts.uiBold,
            fontSize: 21,
            color: PdfColors.white,
            letterSpacing: 2.2,
          ),
        ),
        pw.SizedBox(height: 7),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            // Solid pre-blended colors — see _band header comment.
            color: _bandChipBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
            border: pw.Border.all(color: _bandChipBorder),
          ),
          child: pw.Text(
            slip.slipNo,
            style: pw.TextStyle(
              font: fonts.uiBold,
              fontSize: 14,
              color: PdfColors.white,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Identity strip — Vehicle plate (wide cell, light surface) + 4
  // smaller label/value cells (Plant, Machine, Line items, Dispatched).
  // ───────────────────────────────────────────────────────────────────
  static pw.Widget _identity(
    DplDispatchSlip slip,
    _SlipFonts fonts,
    DateFormat dateFmt,
    DateFormat timeFmt,
    DateTime? referenceTime,
  ) {
    final machineLabel = _machineLabel(slip);
    // Headline part description — short `description` code only
    // (e.g. "114ZY"), styled like a vehicle plate so the gate can
    // read it at a glance. For multi-item slips we still show the
    // first item's code with "+ N more" so the gate knows the slip
    // carries other parts; the full per-item table is below.
    final firstItem = slip.firstItem;
    final partDescription = firstItem == null
        ? '-'
        : (firstItem.description.trim().isNotEmpty
              ? firstItem.description.trim()
              : '-');
    final partSub = firstItem == null
        ? null
        : (slip.items.length > 1 ? '+ ${slip.items.length - 1} more' : null);
    final dateStr = referenceTime == null
        ? '-'
        : dateFmt.format(referenceTime.toLocal());
    final timeStr = referenceTime == null
        ? null
        : '${timeFmt.format(referenceTime.toLocal())} IST';

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line)),
      ),
      // Default crossAxisAlignment (center) — `stretch` would feed
      // each Expanded child `minHeight: constraints.maxHeight` and,
      // since this Row sits inside a Column with unbounded height,
      // that constraint becomes infinity, which silently breaks
      // layout (the children render but the section stays blank in
      // the rasterised preview). Center keeps the content rendering.
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 14,
            child: _idCell(
              background: _surface,
              leftBorder: false,
              child: _plateCell(slip, fonts),
            ),
          ),
          pw.Expanded(
            flex: 10,
            child: _idCell(
              child: _labelValue(
                fonts,
                'PLANT',
                slip.plant.name.isEmpty ? '-' : slip.plant.name,
              ),
            ),
          ),
          pw.Expanded(
            flex: 10,
            child: _idCell(child: _labelValue(fonts, 'MACHINE', machineLabel)),
          ),
          pw.Expanded(
            flex: 10,
            child: _idCell(
              child: _platePartCell(fonts, partDescription, partSub),
            ),
          ),
          pw.Expanded(
            flex: 10,
            child: _idCell(
              child: _labelValue(
                fonts,
                'DISPATCHED',
                dateStr,
                subValue: timeStr,
              ),
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
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
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
    _SlipFonts fonts,
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
            fontSize: 11,
            color: _faint,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 6),
        // Plate-style — same font + ink + letter-spacing pattern as
        // the VEHICLE plate so PLANT / MACHINE / DISPATCHED read as
        // matching "plates" across the identity strip.
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

  static pw.Widget _plateCell(DplDispatchSlip slip, _SlipFonts fonts) {
    final plate = slip.vehicleNo.isEmpty ? '-' : slip.vehicleNo;
    final notes = slip.notes.trim();

    // Step the font size down for longer plates so the full string
    // always fits on one line. Indian commercial plates run anywhere
    // from 8 chars (MH12HV40) to 13+ with separators (MH-12-HV-4040).
    // Letter spacing tracks the size — tight spacing on long plates
    // keeps the gate-scannable look without overflowing the cell.
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
            fontSize: 11,
            color: _faint,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 5),
        // FittedBox handles the long-tail (15+ char) plates that the
        // step-down sizes above don't cover — it scales the text to
        // the cell's bounded width without further font-size logic.
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
        if (notes.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.RichText(
            text: pw.TextSpan(
              style: pw.TextStyle(
                font: fonts.uiMedium,
                fontSize: 11,
                color: _muted,
              ),
              children: [
                const pw.TextSpan(text: 'Dispatch note  ·  '),
                pw.TextSpan(
                  text: notes,
                  style: pw.TextStyle(
                    font: fonts.uiBold,
                    fontSize: 11,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Plate-style cell for the headline part-description code (e.g.
  /// "114ZY"). Mirrors `_plateCell`'s typography on purpose so the
  /// gate sees two big bold "plates" side by side — VEHICLE on the
  /// left, PART DESCRIPTION further along the strip.
  static pw.Widget _platePartCell(
    _SlipFonts fonts,
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
            fontSize: 11,
            color: _faint,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 5),
        // FittedBox(scaleDown) so longer codes (e.g. "109D1-Spacer") shrink
        // to fit the cell width on one line instead of being clipped to
        // "109D1-". Mirrors the VEHICLE plate cell's handling above.
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

  // ───────────────────────────────────────────────────────────────────
  // Parts table — header strip, one row per item, then the total row.
  // ───────────────────────────────────────────────────────────────────
  static pw.Widget _parts(
    DplDispatchSlip slip,
    _SlipFonts fonts,
    NumberFormat fmt,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _partsHeader(fonts),
        for (var i = 0; i < slip.items.length; i++)
          _partRow(
            fonts: fonts,
            fmt: fmt,
            index: i + 1,
            item: slip.items[i],
            isLast: i == slip.items.length - 1,
          ),
        // TOTAL DISPATCHED row — intentionally hidden. Re-enable by
        // uncommenting the call below; the helper itself is kept.
        // _totalRow(slip, fonts, fmt),
      ],
    );
  }

  static pw.Widget _partsHeader(_SlipFonts fonts) {
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
          pw.Expanded(flex: 6, child: pw.Text('CUSTOMER P/N', style: style)),
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              'QUANTITY',
              textAlign: pw.TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _partRow({
    required _SlipFonts fonts,
    required NumberFormat fmt,
    required int index,
    required DplDispatchSlipItem item,
    required bool isLast,
  }) {
    final idxStr = index.toString().padLeft(2, '0');
    final partName = item.partName.trim().isNotEmpty
        ? item.partName
        : (item.description.trim().isNotEmpty
              ? item.description
              : item.partLabel);
    final hasSub =
        item.description.trim().isNotEmpty &&
        item.description.trim() != partName.trim();

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: pw.BoxDecoration(
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
                fontSize: 13,
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
                // Plate-style — Inter Bold ink, matches the VEHICLE
                // plate's pattern at a smaller table-friendly size.
                pw.Text(
                  partName,
                  style: pw.TextStyle(
                    font: fonts.uiBold,
                    fontSize: 18,
                    color: _ink,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                ),
                if (hasSub) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    item.description.trim(),
                    style: pw.TextStyle(
                      font: fonts.uiBold,
                      fontSize: 14,
                      color: _brand,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                ],
              ],
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: pw.Text(
              item.customerPartNo.isEmpty ? '-' : item.customerPartNo,
              style: pw.TextStyle(
                font: fonts.uiBold,
                fontSize: 18,
                color: _ink,
                letterSpacing: 0.6,
              ),
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),
          pw.SizedBox(
            width: 130,
            child: pw.RichText(
              textAlign: pw.TextAlign.right,
              text: pw.TextSpan(
                style: pw.TextStyle(
                  font: fonts.uiBold,
                  fontSize: 23,
                  color: _ink,
                  letterSpacing: 0.8,
                ),
                children: [
                  pw.TextSpan(text: fmt.format(item.qty)),
                  pw.TextSpan(
                    text: '  NOS',
                    style: pw.TextStyle(
                      font: fonts.uiBold,
                      fontSize: 13,
                      color: _muted,
                      letterSpacing: 0.4,
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

  // Kept for re-enabling the TOTAL DISPATCHED row by uncommenting
  // the `_totalRow(...)` call inside `_parts(...)`.
  // ignore: unused_element
  static pw.Widget _totalRow(
    DplDispatchSlip slip,
    _SlipFonts fonts,
    NumberFormat fmt,
  ) {
    final count = slip.items.length;
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color: _surface,
        border: pw.Border(top: pw.BorderSide(color: _ink, width: 1.4)),
      ),
      padding: const pw.EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(width: 28),
          pw.Expanded(
            flex: 11,
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
                  count == 1
                      ? '1 line item  ·  quantity verified at loading'
                      : '$count line items  ·  all quantities verified at loading',
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
          pw.Expanded(flex: 6, child: pw.SizedBox()),
          pw.SizedBox(
            width: 90,
            child: pw.RichText(
              textAlign: pw.TextAlign.right,
              text: pw.TextSpan(
                style: pw.TextStyle(
                  font: fonts.displayBold,
                  fontSize: 23,
                  color: _brand,
                ),
                children: [
                  pw.TextSpan(text: fmt.format(slip.totalQty)),
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

  // ───────────────────────────────────────────────────────────────────
  // Sign-off strip — PDI checkpoint only. QA was removed at the
  // operator's request; PDI now takes the full slip width.
  // ───────────────────────────────────────────────────────────────────
  static pw.Widget _signoff(
    DplDispatchSlip slip,
    _SlipFonts fonts,
    DateFormat dateFmt,
  ) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line)),
      ),
      child: _checkpoint(
        fonts: fonts,
        dateFmt: dateFmt,
        title: 'Pre-Dispatch Inspection  ·  PDI',
        description: 'Final loading check against this manifest.',
        state: slip.pdiState,
        approver: slip.pdiApproval,
        rejection: slip.rejection?.isPdi == true ? slip.rejection : null,
        leftBorder: false,
      ),
    );
  }

  static pw.Widget _checkpoint({
    required _SlipFonts fonts,
    required DateFormat dateFmt,
    required String title,
    required String description,
    required DispatchStationState state,
    required DplDispatchSlipActor? approver,
    required DplDispatchSlipRejection? rejection,
    required bool leftBorder,
  }) {
    final palette = _paletteFor(state);
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: leftBorder
              ? const pw.BorderSide(color: _lineSoft)
              : pw.BorderSide.none,
        ),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: pw.Container(width: 3, color: palette.bar),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _tickBadge(palette),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          font: fonts.uiBold,
                          fontSize: 11.5,
                          color: _ink,
                          letterSpacing: 0.2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        description,
                        style: pw.TextStyle(
                          font: fonts.uiSemiBold,
                          fontSize: 10,
                          color: _muted,
                        ),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _chip(fonts, _chipLabel(state), palette),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: _signBlock(
                              fonts: fonts,
                              dateFmt: dateFmt,
                              state: state,
                              approver: approver,
                              rejection: rejection,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tickBadge(_CheckpointPalette palette) {
    return pw.Container(
      width: 24,
      height: 24,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: palette.bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: palette.line),
      ),
      child: pw.SizedBox(
        width: 12,
        height: 12,
        child: pw.SvgImage(
          svg: _tickSvg.replaceAll('currentColor', _rgbHex(palette.ink)),
        ),
      ),
    );
  }

  static pw.Widget _chip(
    _SlipFonts fonts,
    String label,
    _CheckpointPalette palette,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: pw.BoxDecoration(
        color: palette.bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(999)),
        border: pw.Border.all(color: palette.line),
      ),
      child: pw.Text(
        label.toUpperCase(),
        style: pw.TextStyle(
          font: fonts.uiBold,
          fontSize: 12,
          color: palette.ink,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  static pw.Widget _signBlock({
    required _SlipFonts fonts,
    required DateFormat dateFmt,
    required DispatchStationState state,
    required DplDispatchSlipActor? approver,
    required DplDispatchSlipRejection? rejection,
  }) {
    switch (state) {
      case DispatchStationState.approved:
        return _signed(
          fonts: fonts,
          dateFmt: dateFmt,
          name: (approver?.name.trim().isEmpty ?? true)
              ? '-'
              : approver!.name.trim(),
          at: approver?.at,
        );
      case DispatchStationState.rejected:
        return _signed(
          fonts: fonts,
          dateFmt: dateFmt,
          name: (rejection?.name.trim().isEmpty ?? true)
              ? '-'
              : rejection!.name.trim(),
          at: rejection?.at,
          reason: rejection?.reason,
        );
      case DispatchStationState.pending:
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              height: 12,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _line)),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'INSPECTOR SIGNATURE & TIME',
              style: pw.TextStyle(
                font: fonts.uiBold,
                fontSize: 7.5,
                color: _faint,
                letterSpacing: 1.0,
              ),
            ),
          ],
        );
    }
  }

  static pw.Widget _signed({
    required _SlipFonts fonts,
    required DateFormat dateFmt,
    required String name,
    DateTime? at,
    String? reason,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          name,
          style: pw.TextStyle(font: fonts.uiBold, fontSize: 10, color: _ink),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
        if (at != null) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            '${dateFmt.format(at.toLocal())} IST',
            style: pw.TextStyle(
              font: fonts.uiSemiBold,
              fontSize: 8.5,
              color: _muted,
            ),
          ),
        ],
        if (reason != null && reason.trim().isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            '"${reason.trim()}"',
            style: pw.TextStyle(
              font: fonts.uiSemiBold,
              fontSize: 8,
              color: _rejectedInk,
              fontStyle: pw.FontStyle.italic,
            ),
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
          ),
        ],
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Two-column body — QR sidebar on the left, parts table + signoff
  // on the right. Uses `pw.Table` so the QR sidebar is always visible
  // regardless of how many parts the slip carries. With Row+Expanded
  // the BarcodeWidget kept failing to measure inside unbounded-height
  // parents; Table gives both cells explicit, bounded column widths
  // and reliable cell sizing, which finally makes the QR show up
  // alongside multi-item slips too.
  // ───────────────────────────────────────────────────────────────────
  static pw.Widget _bodyRow(
    DplDispatchSlip slip,
    _SlipFonts fonts,
    NumberFormat fmt,
    DateFormat signDateFmt,
  ) {
    return pw.Table(
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
      columnWidths: const {
        0: pw.FixedColumnWidth(190),
        1: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            _verifySidebar(slip, fonts),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                _parts(slip, fonts, fmt),
                _signoff(slip, fonts, signDateFmt),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Left sidebar — "SCAN TO VERIFY" header + framed QR + trust
  /// footnote, stacked in a Column with explicit widths everywhere so
  /// the QR can never fail to measure.
  static pw.Widget _verifySidebar(DplDispatchSlip slip, _SlipFonts fonts) {
    final payload = slip.qrPayload;
    final hasQr = payload != null && payload.isNotEmpty;
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
                      data: payload,
                      color: _ink,
                      drawText: false,
                    ),
                  )
                : pw.Center(
                    child: pw.Text(
                      'QR appears after\nPDI approval',
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
            'Scan to verify against the Vistar Pulse server  ·  HMAC-signed',
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

  // ───────────────────────────────────────────────────────────────────
  // Activity strip — the slip's audit trail (Requested → PDI approved /
  // rejected → Dispatched), laid out as a single full-width horizontal
  // row so it adds minimal height and the whole slip stays on one page.
  // Mirrors the on-screen `_Timeline` entry logic 1:1 so download = view.
  // ───────────────────────────────────────────────────────────────────
  static pw.Widget _activity(
    DplDispatchSlip slip,
    _SlipFonts fonts,
    DateFormat dateFmt,
  ) {
    final requestedName = _actorName(slip.requestedBy?.name);
    final dispatchedName = _actorName(slip.dispatchedBy?.name);

    final entries = <_ActivityEntry>[
      if (slip.requestedBy != null || slip.requestedAt != null)
        _ActivityEntry(
          svg: _sendSvg,
          label: 'Requested by $requestedName',
          at: slip.requestedAt,
        ),
      if (slip.pdiApproval != null)
        _ActivityEntry(
          svg: _checkCircleSvg,
          label: 'PDI approved by ${_actorName(slip.pdiApproval!.name)}',
          at: slip.pdiApproval!.at,
          remarks: slip.pdiApproval!.remarks,
        ),
      if (slip.rejection != null)
        _ActivityEntry(
          svg: _xCircleSvg,
          label:
              '${slip.rejection!.role.toUpperCase()} rejected by '
              '${_actorName(slip.rejection!.name)}',
          at: slip.rejection!.at,
          remarks: slip.rejection!.reason,
          danger: true,
        ),
      if (slip.dispatchedAt != null)
        _ActivityEntry(
          svg: _truckSvg,
          label: 'Dispatched by $dispatchedName',
          at: slip.dispatchedAt,
        ),
    ];

    // No audit trail yet → render nothing (no empty bordered strip).
    if (entries.isEmpty) return pw.SizedBox();

    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line)),
      ),
      padding: const pw.EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            'ACTIVITY',
            style: pw.TextStyle(
              font: fonts.uiBold,
              fontSize: 11,
              color: _faint,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),
          // Default cross-axis (start) — not `stretch`. The Row sits in a
          // Column with unbounded height, so stretch would feed each
          // Expanded child an infinite minHeight and silently break the
          // layout (see the identity-strip note above).
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < entries.length; i++)
                pw.Expanded(
                  child: _activityCell(
                    fonts,
                    dateFmt,
                    entries[i],
                    leftBorder: i != 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _activityCell(
    _SlipFonts fonts,
    DateFormat dateFmt,
    _ActivityEntry entry, {
    required bool leftBorder,
  }) {
    final ink = entry.danger ? _rejectedInk : _brand;
    final badgeBg = entry.danger ? _rejectedBg : _brandTint;
    final badgeLine = entry.danger ? _rejectedLine : _bandChipBorder;

    return pw.Container(
      padding: pw.EdgeInsets.only(left: leftBorder ? 14 : 0, right: 14),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: leftBorder
              ? const pw.BorderSide(color: _lineSoft)
              : pw.BorderSide.none,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 22,
            height: 22,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: badgeBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: badgeLine),
            ),
            child: pw.SizedBox(
              width: 12,
              height: 12,
              child: pw.SvgImage(
                svg: entry.svg.replaceAll('currentColor', _rgbHex(ink)),
              ),
            ),
          ),
          pw.SizedBox(width: 9),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  entry.label,
                  style: pw.TextStyle(
                    font: fonts.uiBold,
                    fontSize: 10.5,
                    color: _ink,
                  ),
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                ),
                if (entry.at != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    dateFmt.format(entry.at!.toLocal()),
                    style: pw.TextStyle(
                      font: fonts.uiSemiBold,
                      fontSize: 9,
                      color: _muted,
                    ),
                  ),
                ],
                if (entry.remarks != null &&
                    entry.remarks!.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '"${entry.remarks!.trim()}"',
                    style: pw.TextStyle(
                      font: fonts.uiSemiBold,
                      fontSize: 9,
                      color: entry.danger ? _rejectedInk : _muted,
                      fontStyle: pw.FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: pw.TextOverflow.clip,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Trims an actor name and falls back to "-" when blank — keeps the
  /// activity row from rendering a dangling "Requested by " with no name.
  static String _actorName(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? '-' : trimmed;
  }

  // ───────────────────────────────────────────────────────────────────
  // Foot strip — slip ID on the left + "Generated by …" on the right.
  // ───────────────────────────────────────────────────────────────────
  static pw.Widget _foot(DplDispatchSlip slip, _SlipFonts fonts) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line)),
      ),
      padding: const pw.EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            slip.slipNo,
            style: pw.TextStyle(
              font: fonts.monoMedium,
              fontSize: 8.5,
              color: _footId,
            ),
          ),
          pw.Text(
            'Generated by Vistar Pulse  ·  Page 1 of 1',
            style: pw.TextStyle(
              font: fonts.uiSemiBold,
              fontSize: 8,
              color: _muted,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────────

  /// Compact `#rrggbb` hex for a colour — used to inject the
  /// stroke colour into the inline SVG icons. `PdfColor.toHex()`
  /// returns `#rrggbbaa`; we strip the alpha so SVG parses it as a
  /// 6-digit hex without interpreting the trailing pair as alpha.
  static String _rgbHex(PdfColor color) {
    final raw = color.toHex();
    // raw is `#rrggbbaa` (9 chars) — keep only `#rrggbb`.
    return raw.length >= 7 ? raw.substring(0, 7) : raw;
  }

  /// Surface a single machine name when the slip's items all share one;
  /// otherwise expose the count so the identity strip stays honest about
  /// what's on board.
  static String _machineLabel(DplDispatchSlip slip) {
    if (slip.items.isEmpty) return slip.machineLabel;
    final names = slip.items
        .map((it) => it.machineLabel.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (names.length <= 1) {
      return names.isEmpty ? slip.machineLabel : names.first;
    }
    return '${names.length} machines';
  }

  static String _chipLabel(DispatchStationState s) {
    switch (s) {
      case DispatchStationState.approved:
        return 'Passed';
      case DispatchStationState.pending:
        return 'Pending';
      case DispatchStationState.rejected:
        return 'Rejected';
    }
  }

  static _CheckpointPalette _paletteFor(DispatchStationState s) {
    switch (s) {
      case DispatchStationState.approved:
        return const _CheckpointPalette(
          bar: _emeraldLine,
          bg: _emeraldBg,
          ink: _emeraldInk,
          line: _emeraldLine,
        );
      case DispatchStationState.rejected:
        return const _CheckpointPalette(
          bar: _rejectedLine,
          bg: _rejectedBg,
          ink: _rejectedInk,
          line: _rejectedLine,
        );
      case DispatchStationState.pending:
        return const _CheckpointPalette(
          bar: _amberLine,
          bg: _amberBg,
          ink: _amberInk,
          line: _amberLine,
        );
    }
  }
}

class _CheckpointPalette {
  final PdfColor bar;
  final PdfColor bg;
  final PdfColor ink;
  final PdfColor line;
  const _CheckpointPalette({
    required this.bar,
    required this.bg,
    required this.ink,
    required this.line,
  });
}

/// One row in the printed Activity strip — the PDF twin of the on-screen
/// `_TimelineEntry`. [svg] is the inline icon (with `currentColor`),
/// [danger] flips the palette to red for rejections.
class _ActivityEntry {
  final String svg;
  final String label;
  final DateTime? at;
  final String? remarks;
  final bool danger;
  const _ActivityEntry({
    required this.svg,
    required this.label,
    required this.at,
    this.remarks,
    this.danger = false,
  });
}

/// Holds the loaded `pw.Font` instances we use across the slip. Loaded
/// once per build via `PdfGoogleFonts` — falls back to Helvetica if the
/// device can't reach Google's font CDN, so the PDF still renders
/// (without the Vistar Pulse type but with all the right content).
class _SlipFonts {
  final pw.Font displayBold;
  final pw.Font displaySemiBold;
  final pw.Font uiRegular;
  final pw.Font uiMedium;
  final pw.Font uiSemiBold;
  final pw.Font uiBold;
  final pw.Font monoMedium;

  const _SlipFonts({
    required this.displayBold,
    required this.displaySemiBold,
    required this.uiRegular,
    required this.uiMedium,
    required this.uiSemiBold,
    required this.uiBold,
    required this.monoMedium,
  });

  static Future<_SlipFonts> load() async {
    try {
      final results = await Future.wait([
        PdfGoogleFonts.sairaCondensedBold(),
        PdfGoogleFonts.sairaCondensedSemiBold(),
        PdfGoogleFonts.interRegular(),
        PdfGoogleFonts.interMedium(),
        PdfGoogleFonts.interSemiBold(),
        PdfGoogleFonts.interBold(),
        PdfGoogleFonts.jetBrainsMonoMedium(),
      ]);
      return _SlipFonts(
        displayBold: results[0],
        displaySemiBold: results[1],
        uiRegular: results[2],
        uiMedium: results[3],
        uiSemiBold: results[4],
        uiBold: results[5],
        monoMedium: results[6],
      );
    } catch (_) {
      // Network unreachable or Google Fonts CDN blocked — fall back to
      // the built-in Helvetica family so the PDF still renders.
      final regular = pw.Font.helvetica();
      final bold = pw.Font.helveticaBold();
      return _SlipFonts(
        displayBold: bold,
        displaySemiBold: bold,
        uiRegular: regular,
        uiMedium: regular,
        uiSemiBold: bold,
        uiBold: bold,
        monoMedium: pw.Font.courier(),
      );
    }
  }
}
