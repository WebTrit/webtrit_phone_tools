import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

class MakeRunner {
  const MakeRunner({required this.logger});

  final Logger logger;

  Future<void> configureSplash(String workingDirectory) async {
    await _runMakeCommand(workingDirectory, 'generate-native-splash');
  }

  Future<void> configureLaunchIcons(String workingDirectory) async {
    await _runMakeCommand(workingDirectory, 'generate-launcher-icons');
  }

  Future<void> configurePlatformIdentifiers(String workingDirectory) async {
    await _runMakeCommand(workingDirectory, 'rename-package');
  }

  Future<void> _runMakeCommand(String workingDirectory, String target) async {
    final process = await Process.run(
      'make',
      [target],
      workingDirectory: workingDirectory,
    );

    final stderr = process.stderr.toString().trim();
    logger.info(process.stdout.toString().trim());
    if (stderr.isNotEmpty) {
      process.exitCode != 0 ? logger.err(stderr) : logger.detail(stderr);
    }
    logger.info('Make command "$target" finished with: ${process.exitCode}');
  }
}
