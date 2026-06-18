import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import '../models/models.dart';

class MetadataProcessor {
  const MetadataProcessor({required this.logger});

  final Logger logger;

  void writeCodeSigningIdentity({
    required String metadataPath,
    required String identity,
  }) {
    logger.info('Writing $codeSigningIdentityKey to: ${path.basename(metadataPath)}');
    final metadata = _readMetadata(metadataPath);
    metadata[codeSigningIdentityKey] = identity;

    final content = (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(metadata))).toString();
    File(metadataPath).writeAsStringSync(content, flush: true);
  }

  Map<String, dynamic> _readMetadata(String metadataPath) {
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
}
