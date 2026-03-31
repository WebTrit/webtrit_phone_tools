import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../models/app_configure_context.dart';

class FirebaseRunner {
  const FirebaseRunner({required this.logger});

  final Logger logger;

  Future<void> configure(AppConfigureContext context) async {
    logger
      ..info('Starting Firebase configuration for account: ${context.firebaseAccountId}')
      ..info('Working directory: ${context.workingDirectoryPath}')
      ..info('Android bundle ID: ${context.bundleIdAndroid}')
      ..info('iOS bundle ID: ${context.bundleIdIos}')
      ..info('Service account path: ${context.firebaseServiceAccountPath}')
      ..info('Running flutterfire configure process, with service account: ${context.firebaseServiceAccountPath}');

    final process = await Process.start(
      'flutterfire',
      [
        'configure',
        '--yes',
        '--project=${context.firebaseAccountId}',
        '--android-package-name=${context.bundleIdAndroid}',
        '--ios-bundle-id=${context.bundleIdIos}',
        '--service-account=${context.firebaseServiceAccountPath}',
        '--platforms',
        'android,ios',
      ],
      workingDirectory: context.workingDirectoryPath,
      runInShell: true,
    );

    final stdoutFuture =
        process.stdout.transform(utf8.decoder).forEach((data) => logger.info('stdout: ${data.trim()}'));
    final stderrFuture = process.stderr.transform(utf8.decoder).forEach((data) => logger.err('stderr: ${data.trim()}'));

    await Future.wait([stdoutFuture, stderrFuture]);
    final exitCode = await process.exitCode;

    logger.info('flutterfire finished with exit code: $exitCode');

    if (exitCode != 0) {
      logger.err('Flutterfire process failed with exit code $exitCode. Please check the logs above for details.');
      throw Exception('Flutterfire configuration failed with exit code $exitCode');
    }
  }
}
