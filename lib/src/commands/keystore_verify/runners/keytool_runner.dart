import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

class KeytoolRunner {
  const KeytoolRunner({required this.logger});

  final Logger logger;

  String getSHA256({
    required String keystorePath,
    required String storePassword,
  }) {
    final process = Process.runSync(
      'keytool',
      ['-list', '-v', '-keystore', keystorePath, '-storepass', storePassword],
      runInShell: true,
    );

    if (process.exitCode != 0) {
      logger
        ..info(process.stdout.toString())
        ..err(process.stderr.toString());
      throw Exception('An error occurred while opening keystore: $keystorePath');
    }

    final output = process.stdout.toString();
    final exp = RegExp(r'SHA256:\s*([0-9A-Fa-f:]+)');
    final match = exp.stringMatch(output);

    if (match == null) throw Exception('SHA256 fingerprint not found in keystore: $keystorePath');

    return match;
  }
}
