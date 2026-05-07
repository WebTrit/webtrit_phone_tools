import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../models/models.dart';

class FirebaseSetupRunner {
  const FirebaseSetupRunner({required this.logger});

  final Logger logger;

  Future<void> configure(AppSetupContext context) async {
    logger
      ..info('Running flutterfire configure for platform(s): ${context.platforms.map((p) => p.name).join(', ')}')
      ..info('Firebase project: ${context.firebaseAccountId}')
      ..info('Service account: ${context.firebaseServiceAccountPath}');

    final process = await Process.start(
      'flutterfire',
      [
        'configure',
        '--yes',
        '--project=${context.firebaseAccountId}',
        '--android-package-name=${context.bundleIdAndroid}',
        '--ios-bundle-id=${context.bundleIdIos}',
        '--service-account=${context.firebaseServiceAccountPath}',
        '--platforms=${context.platforms.map((p) => p.flutterfirePlatformFlag).join(',')}',
      ],
      workingDirectory: context.workingDirectoryPath,
      runInShell: true,
    );

    final stderrBuffer = StringBuffer();
    final stdoutFuture = process.stdout.transform(utf8.decoder).forEach((data) => logger.info(data.trim()));
    final stderrFuture = process.stderr.transform(utf8.decoder).forEach(stderrBuffer.write);

    await Future.wait([stdoutFuture, stderrFuture]);
    final exitCode = await process.exitCode;

    final stderr = stderrBuffer.toString().trim();
    if (stderr.isNotEmpty) {
      exitCode != 0 ? logger.err(stderr) : logger.detail(stderr);
    }

    logger.info('flutterfire finished with exit code: $exitCode');

    if (exitCode != 0) {
      throw Exception('flutterfire configure failed with exit code $exitCode');
    }
  }
}
