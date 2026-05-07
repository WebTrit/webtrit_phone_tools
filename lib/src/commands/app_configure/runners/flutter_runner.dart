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

    _logProcess(flutterGenProcess, 'Flutter gen activation');

    final firebaseProcess = await Process.run(
      'dart',
      ['pub', 'global', 'activate', 'flutterfire_cli'],
      workingDirectory: workingDirectory,
    );

    _logProcess(firebaseProcess, 'Flutterfire CLI activation');
  }

  Future<void> configureLocalization(String workingDirectory) async {
    final process = await Process.run(
      'flutter',
      ['gen-l10n'],
      workingDirectory: workingDirectory,
    );

    _logProcess(process, 'Localization generation');
  }

  Future<void> configureAssets(String workingDirectory) async {
    final process = await Process.run(
      'fluttergen',
      [],
      workingDirectory: workingDirectory,
    );

    _logProcess(process, 'Flutter gen');
  }

  void _logProcess(ProcessResult process, String label) {
    final stdout = process.stdout.toString().trim();
    final stderr = process.stderr.toString().trim();
    if (stdout.isNotEmpty) logger.info(stdout);
    if (stderr.isNotEmpty) {
      process.exitCode != 0 ? logger.err(stderr) : logger.detail(stderr);
    }
    logger.info('$label finished with: ${process.exitCode}');
  }
}
