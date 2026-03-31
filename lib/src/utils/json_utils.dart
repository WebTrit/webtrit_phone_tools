import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Writes [content] to [path] as a pretty-printed JSON string.
Future<void> writeJsonToFile(String path, dynamic content, {Logger? logger}) async {
  try {
    final file = File(path);
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(content);
    await file.writeAsString(jsonString);

    logger?.success('✓ Config written: $path');
  } catch (e) {
    logger?.err('✗ Failed to write JSON to $path: $e');
    rethrow;
  }
}
