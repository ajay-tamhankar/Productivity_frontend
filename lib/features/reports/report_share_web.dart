import 'dart:typed_data';
import 'report_download_web.dart';

Future<void> shareReportBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? text,
}) async {
  await saveReportBytes(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}
