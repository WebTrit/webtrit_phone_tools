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

    logger
      ..info(process.stdout.toString().trim())
      ..err(process.stderr.toString().trim())
      ..info('Make command "$target" finished with: ${process.exitCode}');
  }
}
