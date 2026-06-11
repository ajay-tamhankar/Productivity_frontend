import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/dpl_dispatch_slip.dart';

/// Builds a print-ready PDF that mirrors the operators' existing
/// printed paper slip (reference photo shared by the user):
///
///   * **Landscape** orientation
///   * One bordered table with 5 horizontal rows, no header strip:
///     1. Full part description (uppercase, bold)
///     2. Customer P/N (large bold)
///     3. QTY in NOS
///     4. Reference datetime (`d-M-yy h:mm a` to match the paper)
///     5. `QA: …`  +  `PDI: …` side by side
///   * Below the table: QR (left) + a tight human-readable summary
///     panel (right) so the slip is verifiable AND eye-readable.
///
/// All text uses Helvetica's WinAnsi character set only — pure ASCII
/// separators (`-`, `:`), no `•` bullets or `—` em-dashes so the PDF
/// never renders the missing-glyph `█` boxes we hit on the first pass.
class DispatchSlipPdfBuilder {
  const DispatchSlipPdfBuilder._();

  static const String _sep = ' - ';

  static Future<Uint8List> build(
    DplDispatchSlip slip, {
    String? organizationLabel,
  }) async {
    final fmt = NumberFormat.decimalPattern();
    final paperDateFmt = DateFormat('d-M-yy  h:mm a');
    final sigDateFmt = DateFormat('dd MMM yyyy, HH:mm');

    final partTitle = (slip.partName.trim().isNotEmpty
            ? slip.partName
            : (slip.description.trim().isNotEmpty
                ? slip.description
                : slip.partLabel))
        .toUpperCase();
    final referenceTime = slip.pdiApproval?.at ??
        slip.qaApproval?.at ??
        slip.requestedAt;

    final doc = pw.Document(
      title: 'Dispatch Slip ${slip.slipNo}',
      author: 'Vistar Pulse',
    );

    doc.addPage(
      pw.Page(
        // Landscape A4 — the original paper slip is landscape and the
        // five rows read most naturally across a wide canvas.
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          // Explicit full-page SizedBox so the inner Column stretches
          // to the page width and height. Without this, pw.Column with
          // crossAxisAlignment.stretch can end up sized to its widest
          // intrinsic child instead of the page, leaving the bordered
          // box hugging the left side of the sheet.
          return pw.SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── The bordered slip body, matching the printed paper ──
                pw.Container(
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.black,
                      width: 2,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _row(
                        pw.Text(
                          partTitle,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        height: 62,
                      ),
                      _row(
                        pw.Text(
                          slip.customerPartNo.isEmpty
                              ? '-'
                              : slip.customerPartNo,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 30,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        height: 70,
                      ),
                      _row(
                        pw.Text(
                          'QTY: ${fmt.format(slip.qty)} NOS',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        height: 60,
                      ),
                      _row(
                        pw.Text(
                          referenceTime == null
                              ? '-'
                              : paperDateFmt.format(referenceTime.toLocal()),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        height: 58,
                      ),
                      _row(
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Expanded(
                              child: _pdfSignatureBlock(
                                station: 'QA',
                                state: slip.qaState,
                                name: slip.qaApproval?.name,
                                at: slip.qaApproval?.at,
                                rejection: slip.rejection?.isQa == true
                                    ? slip.rejection
                                    : null,
                                dateFmt: sigDateFmt,
                              ),
                            ),
                            // Hairline divider so the eye can split QA
                            // from PDI even when both blocks are wide.
                            pw.Container(
                              width: 0.5,
                              height: 56,
                              color: PdfColors.grey400,
                            ),
                            pw.Expanded(
                              child: _pdfSignatureBlock(
                                station: 'PDI',
                                state: slip.pdiState,
                                name: slip.pdiApproval?.name,
                                at: slip.pdiApproval?.at,
                                rejection: slip.rejection?.isPdi == true
                                    ? slip.rejection
                                    : null,
                                dateFmt: sigDateFmt,
                              ),
                            ),
                          ],
                        ),
                        // No bottom border on the last row so the box
                        // has a single clean outer border.
                        isBottomRow: true,
                        height: 80,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 22),

                // ── QR + human-readable summary (below the box) ──
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    border:
                        pw.Border.all(color: PdfColors.grey400, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  child:
                      _pdfQrPanel(slip, fmt, sigDateFmt, organizationLabel),
                ),

                pw.Spacer(),

                pw.Center(
                  child: pw.Text(
                    'Slip ${slip.slipNo}${_sep}Printed via Vistar Pulse',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  /// One row of the bordered slip body. Borders use only horizontal
  /// dividers between rows; the outer container provides the box.
  static pw.Widget _row(
    pw.Widget child, {
    double? height,
    bool isBottomRow = false,
  }) {
    return pw.Container(
      width: double.infinity,
      height: height,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 22),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: isBottomRow
              ? pw.BorderSide.none
              : const pw.BorderSide(color: PdfColors.black, width: 1),
        ),
      ),
      child: pw.Center(child: child),
    );
  }

  /// Mirrors the paper-slip signature cells: `QA: <name>` /
  /// `PDI: <name>` with a small timestamp below. Status colour is
  /// retained as a hint (green for approved, amber for pending, red
  /// for rejected) but the line itself stays compact so it reads at
  /// the same scale as the paper slip's handwritten signature.
  static pw.Widget _pdfSignatureBlock({
    required String station,
    required DispatchStationState state,
    required String? name,
    required DateTime? at,
    required DplDispatchSlipRejection? rejection,
    required DateFormat dateFmt,
  }) {
    final approverName = state == DispatchStationState.approved
        ? ((name?.trim().isEmpty ?? true) ? null : name!.trim())
        : state == DispatchStationState.rejected
            ? ((rejection?.name.trim().isEmpty ?? true)
                ? null
                : rejection!.name.trim())
            : null;
    final stamped = state == DispatchStationState.approved
        ? at
        : state == DispatchStationState.rejected
            ? rejection?.at
            : null;
    final fg = state == DispatchStationState.rejected
        ? PdfColors.red700
        : (state == DispatchStationState.pending
            ? PdfColors.amber700
            : PdfColors.green800);

    // Primary line — "QA: <name>" or "QA: PENDING" / "QA: REJECTED".
    final primary = switch (state) {
      DispatchStationState.approved => '$station: ${approverName ?? "-"}',
      DispatchStationState.pending => '$station: PENDING',
      DispatchStationState.rejected =>
        '$station: REJECTED ${approverName != null ? "($approverName)" : ""}',
    };

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            primary,
            style: pw.TextStyle(
              fontSize: 19,
              fontWeight: pw.FontWeight.bold,
              color: fg,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
          if (stamped != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              dateFmt.format(stamped.toLocal()),
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ],
          if (rejection != null &&
              rejection.reason.trim().isNotEmpty &&
              state == DispatchStationState.rejected) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              '"${rejection.reason}"',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.red700,
                fontStyle: pw.FontStyle.italic,
              ),
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _pdfQrPanel(
    DplDispatchSlip slip,
    NumberFormat fmt,
    DateFormat dateFmt,
    String? organizationLabel,
  ) {
    final payload = slip.qrPayload;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (payload != null && payload.isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(
                errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high,
              ),
              data: payload,
              width: 110,
              height: 110,
            ),
          )
        else
          pw.Container(
            width: 110,
            height: 110,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
            ),
            child: pw.Text(
              'QR available\nafter PDI approval',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        pw.SizedBox(width: 18),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                slip.slipNo,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              if (organizationLabel != null)
                pw.Text(
                  organizationLabel,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              pw.SizedBox(height: 8),
              _kv('Machine', slip.machineLabel),
              _kv(
                'Customer P/N',
                slip.customerPartNo.isEmpty ? '-' : slip.customerPartNo,
              ),
              _kv('Qty', '${fmt.format(slip.qty)} NOS'),
              if (slip.qaApproval != null && slip.qaApproval!.at != null)
                _kv(
                  'QA approved',
                  '${slip.qaApproval!.name}$_sep'
                  '${dateFmt.format(slip.qaApproval!.at!.toLocal())}',
                ),
              if (slip.pdiApproval != null && slip.pdiApproval!.at != null)
                _kv(
                  'PDI approved',
                  '${slip.pdiApproval!.name}$_sep'
                  '${dateFmt.format(slip.pdiApproval!.at!.toLocal())}',
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Scan QR to verify authenticity against the Vistar Pulse '
                'server. The code is HMAC-signed; tampering invalidates it.',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}
