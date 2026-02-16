import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import 'package:data/dto/dto.dart';

import '../../../utils/app_config_factory.dart';

class ExternalGeneratorRunner {
  const ExternalGeneratorRunner({required this.logger});

  final Logger logger;

  Future<void> runGenerators({
    required String workingDirectoryPath,
    required ApplicationDTO application,
    required SplashAssetDto splashInfo,
    required LaunchAssetsEnvelopeDto launchIcons,
  }) async {
    final launchBgColor = launchIcons.entity.source?.backgroundColorHex;

    if (launchBgColor != null) {
      logger.info('- Running: generate-launcher-icons-config');
      final env = AppConfigFactory.createLauncherIconsEnv(launchBgColor);
      await _runMakeCommand(workingDirectoryPath, 'generate-launcher-icons-config', env);
    } else {
      logger.warn('Skipping launcher generation: backgroundColorHex is null.');
    }

    final splashBgColor = splashInfo.source?.backgroundColorHex;
    if (splashBgColor != null) {
      logger.info('- Running: generate-native-splash-config');
      final env = AppConfigFactory.createNativeSplashEnv(splashBgColor);
      await _runMakeCommand(workingDirectoryPath, 'generate-native-splash-config', env);
    } else {
      logger.warn('Skipping splash generation: backgroundColorHex is null.');
    }

    logger.info('- Running: generate-package-config');
    final packageEnv = AppConfigFactory.createPackageConfigEnv(application);
    await _runMakeCommand(workingDirectoryPath, 'generate-package-config', packageEnv);
  }

  Future<void> _runMakeCommand(String workingDirectoryPath, String target, Map<String, String> environment) async {
    logger.info('Running generator: $target...');

    final process = await Process.start(
      'make',
      [target],
      workingDirectory: workingDirectoryPath,
      runInShell: true,
      environment: environment,
    );

    final stdoutFuture = process.stdout.transform(utf8.decoder).forEach((data) => logger.detail(data.trim()));
    final stderrFuture = process.stderr.transform(utf8.decoder).forEach((data) => logger.warn(data.trim()));

    await Future.wait([stdoutFuture, stderrFuture]);
    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw Exception('Command "make $target" failed with exit code $exitCode');
    }
    logger.success('✓ Generator $target completed');
  }
}