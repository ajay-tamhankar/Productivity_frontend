import 'dart:typed_data';
import 'dart:html' as html;

Future<String?> saveReportBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return null;
}
