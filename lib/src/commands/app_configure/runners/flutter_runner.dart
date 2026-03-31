import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

class FlutterRunner {
  const FlutterRunner({required this.logger});

  final Logger logger;

  Future<void> setupDependencies(String workingDirectory) async {
    final flutterGenProcess = await Process.run(
      'dart',
      ['pub', 'global', 'activate', 'flutter_gen'],
      workingDirectory: workingDirectory,
    );

    logger
      ..info(flutterGenProcess.stdout.toString().trim())
      ..err(flutterGenProcess.stderr.toString().trim())
      ..info('Flutter gen activation finished with: ${flutterGenProcess.exitCode}');

    final firebaseProcess = await Process.run(
      'dart',
      ['pub', 'global', 'activate', 'flutterfire_cli'],
      workingDirectory: workingDirectory,
    );

    logger
      ..info(firebaseProcess.stdout.toString().trim())
      ..err(firebaseProcess.stderr.toString().trim())
      ..info('Flutterfire CLI activation finished with: ${firebaseProcess.exitCode}');
  }

  Future<void> configureLocalization(String workingDirectory) async {
    final process = await Process.run(
      'flutter',
      ['gen-l10n'],
      workingDirectory: workingDirectory,
    );

    logger
      ..info(process.stdout.toString().trim())
      ..err(process.stderr.toString().trim())
      ..info('Localization generation finished with: ${process.exitCode}');
  }

  Future<void> configureAssets(String workingDirectory) async {
    final process = await Process.run(
      'fluttergen',
      [],
      workingDirectory: workingDirectory,
    );

    logger
      ..info(process.stdout.toString().trim())
      ..err(process.stderr.toString().trim())
      ..info('Flutter gen finished with: ${process.exitCode}');
  }
}
