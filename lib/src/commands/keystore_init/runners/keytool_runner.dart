import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class KeytoolRunner {
  const KeytoolRunner({required this.logger});

  final Logger logger;

  String? extractFingerprint({required String keystoreProjectPath}) {
    final metadataFile = File(path.join(keystoreProjectPath, 'upload-keystore-metadata.json'));
    if (!metadataFile.existsSync()) {
      logger.err('Keystore not provided.');
      return null;
    }

    final metadata = jsonDecode(metadataFile.readAsStringSync()) as Map<String, dynamic>;
    final keyPassword = metadata['keyPassword'];
    final storeFileP12 = metadata['storeFile'];

    final command = [
      '-c',
      'keytool -list -v -keystore $storeFileP12 -storetype PKCS12 -storepass $keyPassword | grep SHA256'
    ];
    final process = Process.runSync(
      'sh',
      command,
      workingDirectory: keystoreProjectPath,
      runInShell: true,
    );

    if (process.exitCode == 0) {
      final output = process.stdout as String;
      final regex = RegExp(r'SHA256:\s*([\w:]+)');
      final match = regex.firstMatch(output);
      if (match != null) {
        return match.group(1);
      } else {
        logger.err('SHA256 hash not found in the output.');
      }
    } else {
      logger.err('Error running keytool command: ${process.stderr ?? process.stdout}, command: $command');
    }

    return null;
  }
}
