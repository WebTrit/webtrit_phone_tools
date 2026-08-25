import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// Reads and updates `upload-store-connect-metadata.json`, the file a keystore
/// folder carries with everything the release pipeline needs to reach Apple.
class SigningMetadataProcessor {
  const SigningMetadataProcessor({required this.logger});

  final Logger logger;

  Map<String, dynamic> read(String metadataPath) {
    final file = File(metadataPath);
    if (!file.existsSync()) {
      return <String, dynamic>{};
    }

    final content = file.readAsStringSync().trim();
    if (content.isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(content) as Map<String, dynamic>;
  }

  void write({
    required String metadataPath,
    required String key,
    required String value,
  }) {
    logger.info('Writing $key to: ${path.basename(metadataPath)}');
    final metadata = read(metadataPath)..[key] = value;
    final content = (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(metadata))).toString();
    File(metadataPath).writeAsStringSync(content, flush: true);
  }
}
