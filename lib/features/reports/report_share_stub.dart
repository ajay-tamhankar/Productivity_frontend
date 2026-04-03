import 'dart:typed_data';

Future<void> shareReportBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? text,
}) async {
  throw UnsupportedError('Share is not supported on this platform yet.');
}
