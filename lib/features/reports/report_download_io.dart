import 'dart:io';
import 'dart:typed_data';

Future<String?> saveReportBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final candidates = <Directory>[
    if (Platform.isAndroid) Directory('/storage/emulated/0/Download'),
    ..._downloadDirectoryCandidates(),
    Directory.systemTemp,
  ];

  Object? lastError;
  for (final dir in candidates) {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      lastError = e;
    }
  }

  throw Exception('Unable to save exported file on this device. $lastError');
}

List<Directory> _downloadDirectoryCandidates() {
  final userHome = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (userHome == null || userHome.trim().isEmpty) return const [];

  final home = userHome.trim();
  return <Directory>[
    Directory('$home${Platform.pathSeparator}Downloads'),
    Directory('$home${Platform.pathSeparator}documents'),
  ];
}
