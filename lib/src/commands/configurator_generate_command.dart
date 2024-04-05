import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

class ConfiguratorGenerateCommand extends Command<int> {
  ConfiguratorGenerateCommand({
    required Logger logger,
  }) : _logger = logger;

  @override
  String get name => 'configurator-generate';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Generate resources for customize application',
      );
    return buffer.toString();
  }

  final Logger _logger;

  @override
  Future<int> run() async {
    _logger.info('Flutter gen start');
    final flutterGenProcess = await Process.run(
      'fluttergen',
      [],
    );
    _logger
      ..info(flutterGenProcess.stdout.toString())
      ..err(flutterGenProcess.stderr.toString())
      ..info('Flutter gen finished with: ${flutterGenProcess.exitCode}');

    final flutterIconsProcess = await Process.run(
      'flutter',
      [
        'pub',
        'run',
        'flutter_launcher_icons',
      ],
    );
    _logger
      ..info(flutterIconsProcess.stdout.toString())
      ..err(flutterIconsProcess.stderr.toString())
      ..info('Flutter icons generation finished with: ${flutterIconsProcess.exitCode}');

    final nativeSplashProcess = await Process.run(
      'dart',
      [
        'run',
        'flutter_native_splash:create',
      ],
    );
    _logger
      ..info(nativeSplashProcess.stdout.toString())
      ..err(nativeSplashProcess.stderr.toString())
      ..info('Native splash generation finished with: ${nativeSplashProcess.exitCode}');

    final packageInstallProcess = await Process.run(
      'dart',
      [
        'pub',
        'add',
        'package_rename',
      ],
    );
    _logger
      ..info(packageInstallProcess.stdout.toString())
      ..err(packageInstallProcess.stderr.toString())
      ..info('Package renaming finished with: ${packageInstallProcess.exitCode}');

    final packageRenameProcess = await Process.run(
      'dart',
      [
        'run',
        'package_rename',
      ],
    );
    _logger
      ..info(packageRenameProcess.stdout.toString())
      ..err(packageRenameProcess.stderr.toString())
      ..info('Package renaming finished with: ${packageRenameProcess.exitCode}');

    final buildRunnerProcess = await Process.run(
      'flutter',
      [
        'pub',
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ],
    );
    _logger
      ..info(buildRunnerProcess.stdout.toString())
      ..err(buildRunnerProcess.stderr.toString())
      ..info('Build runner finished with: ${buildRunnerProcess.exitCode}');

    return ExitCode.success.code;
  }
}
