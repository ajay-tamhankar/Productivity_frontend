import 'dart:typed_data';

Future<String?> saveReportBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('File export is not supported on this platform yet.');
}
