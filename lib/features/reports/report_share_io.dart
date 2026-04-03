import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

Future<void> shareReportBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? text,
}) async {
  final dir = Directory.systemTemp;
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: fileName)],
    text: text,
    subject: fileName,
  );
}
