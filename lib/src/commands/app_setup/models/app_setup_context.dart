import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/app_resources/constants/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';

const _argPlatform = 'platform';
const _argKeystorePath = 'keystore-path';
const _argCacheSessionDataPath = 'cache-session-data-path';
const _firebaseServiceAccountFileName = 'build/google-play-service-account.json';

enum SetupPlatform {
  ios,
  android;

  static SetupPlatform fromString(String value) {
    return switch (value) {
      'ios' => SetupPlatform.ios,
      'android' => SetupPlatform.android,
      _ => throw ArgumentError('Unknown platform: "$value". Valid values: ios, android'),
    };
  }

  String get flutterfirePlatformFlag => name;
}

class AppSetupContext {
  const AppSetupContext({
    required this.workingDirectoryPath,
    required this.platforms,
    required this.bundleIdAndroid,
    required this.bundleIdIos,
    required this.firebaseAccountId,
    required this.firebaseServiceAccountPath,
  });

  factory AppSetupContext.fromArgs(ArgResults argResults, Logger logger) {
    final rest = argResults.rest;
    if (rest.length > 1) {
      throw UsageException('Only one directory parameter can be passed.', '');
    }

    final workingDirectoryPath = rest.isEmpty ? Directory.current.path : path.normalize(rest[0]);

    final platformArgs = argResults[_argPlatform] as List<String>;
    if (platformArgs.isEmpty) {
      throw UsageException('--$_argPlatform is required. Use --platform ios, --platform android, or both.', '');
    }
    final platforms = platformArgs.map(SetupPlatform.fromString).toSet().toList();

    final cacheSessionDataPath = (argResults[_argCacheSessionDataPath] as String?) ?? defaultCacheSessionDataPath;
    final absoluteCachePath = path.isAbsolute(cacheSessionDataPath)
        ? path.normalize(cacheSessionDataPath)
        : path.normalize(path.join(workingDirectoryPath, cacheSessionDataPath));

    if (!File(absoluteCachePath).existsSync()) {
      throw UsageException('Cache session data not found at: $absoluteCachePath', '');
    }

    final cacheSessionData = File(absoluteCachePath).readAsStringSync().toMap();

    final keystoreArg = argResults[_argKeystorePath] as String?;
    if (keystoreArg == null || keystoreArg.isEmpty) {
      logger.err('--$_argKeystorePath is required and must point to the platform keystore directory.');
      throw UsageException('Missing keystore path', '');
    }

    final projectKeystorePath = path.isAbsolute(keystoreArg)
        ? path.normalize(keystoreArg)
        : path.normalize(path.join(workingDirectoryPath, keystoreArg));

    if (!Directory(projectKeystorePath).existsSync()) {
      throw UsageException('Keystore directory does not exist: $projectKeystorePath', '');
    }

    final bundleIdAndroid = cacheSessionData[bundleIdAndroidField] as String?;
    if (bundleIdAndroid == null || bundleIdAndroid.isEmpty) {
      throw UsageException('"$bundleIdAndroidField" is missing from cache session data.', '');
    }

    final bundleIdIos = cacheSessionData[bundleIdIosField] as String?;
    if (bundleIdIos == null || bundleIdIos.isEmpty) {
      throw UsageException('"$bundleIdIosField" is missing from cache session data.', '');
    }

    final firebaseServiceAccountPath = path.join(projectKeystorePath, _firebaseServiceAccountFileName);
    if (!File(firebaseServiceAccountPath).existsSync()) {
      throw UsageException('Firebase service account not found at: $firebaseServiceAccountPath', '');
    }

    final firebaseServiceAccount = File(firebaseServiceAccountPath).readAsStringSync().toMap();
    final firebaseAccountId = firebaseServiceAccount[projectIdField] as String?;
    if (firebaseAccountId == null || firebaseAccountId.isEmpty) {
      throw UsageException('"$projectIdField" missing in Firebase service account JSON.', '');
    }

    logger
      ..info('- Platform(s): ${platforms.map((p) => p.name).join(', ')}')
      ..info('- Working directory: $workingDirectoryPath')
      ..info('- Keystore path: $projectKeystorePath')
      ..info('- Android bundle ID: $bundleIdAndroid')
      ..info('- iOS bundle ID: $bundleIdIos')
      ..info('- Firebase project: $firebaseAccountId');

    return AppSetupContext(
      workingDirectoryPath: workingDirectoryPath,
      platforms: platforms,
      bundleIdAndroid: bundleIdAndroid,
      bundleIdIos: bundleIdIos,
      firebaseAccountId: firebaseAccountId,
      firebaseServiceAccountPath: firebaseServiceAccountPath,
    );
  }

  final String workingDirectoryPath;
  final List<SetupPlatform> platforms;
  final String bundleIdAndroid;
  final String bundleIdIos;
  final String firebaseAccountId;
  final String firebaseServiceAccountPath;
}
