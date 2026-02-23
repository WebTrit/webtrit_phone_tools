import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/app_resources/constants/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';

const _bundleIdAndroid = 'bundleIdAndroid';
const _bundleIdIos = 'bundleIdIos';
const _keystorePath = 'keystore-path';
const _cacheSessionDataPath = 'cache-session-data-path';
const _directoryParameterName = '<directory>';
const _firebaseServiceAccountFileName = 'build/google-play-service-account.json';

class AppConfigureContext {
  const AppConfigureContext({
    required this.workingDirectoryPath,
    required this.projectKeystorePath,
    required this.bundleIdAndroid,
    required this.bundleIdIos,
    required this.firebaseAccountId,
    required this.firebaseServiceAccountPath,
  });

  factory AppConfigureContext.fromArgs(ArgResults argResults, Logger logger) {
    final rest = argResults.rest;
    if (rest.length > 1) {
      logger.err('Only one "$_directoryParameterName" parameter can be passed.');
      throw UsageException('Invalid arguments', 'Only one directory parameter allowed.');
    }

    final workingDirectoryPath = rest.isEmpty ? Directory.current.path : path.normalize(rest[0]);

    final cacheSessionDataPath = (argResults[_cacheSessionDataPath] as String?) ?? defaultCacheSessionDataPath;
    final absoluteCachePath = path.normalize(path.join(workingDirectoryPath, cacheSessionDataPath));

    if (!File(absoluteCachePath).existsSync()) {
      logger.err(
        '- The default cache_session_data.json file was not used, generated, or prepared before running this script, '
        'or the custom path to cache session data was not provided correctly.',
      );
      throw Exception('Missing cache session data.');
    }

    final cacheSessionData = File(absoluteCachePath).readAsStringSync().toMap();

    final projectKeystorePathArg = argResults[_keystorePath] as String?;
    final projectKeystorePathBuildConfig = cacheSessionData[keystorePathField] as String?;
    final projectKeystorePath = projectKeystorePathArg ?? projectKeystorePathBuildConfig ?? '';

    if (projectKeystorePath.isEmpty) {
      logger.err(
        'The option $_keystorePath cannot be empty and must be provided as a parameter or through $defaultCacheSessionDataPath',
      );
      throw UsageException('Missing keystore path', 'Provide via flag or cache.');
    }

    final bundleIdAndroid =
        (argResults[_bundleIdAndroid] as String?) ?? cacheSessionData[bundleIdAndroidField] as String?;
    if (bundleIdAndroid == null || bundleIdAndroid.isEmpty) {
      logger.err('Option "$_bundleIdAndroid" can not be empty.');
      throw UsageException('Missing Android Bundle ID', 'Provide via flag or cache.');
    }

    final bundleIdIos = (argResults[_bundleIdIos] as String?) ?? cacheSessionData[bundleIdIosField] as String?;
    if (bundleIdIos == null || bundleIdIos.isEmpty) {
      logger.err('Option "$_bundleIdIos" can not be empty.');
      throw UsageException('Missing iOS Bundle ID', 'Provide via flag or cache.');
    }

    logger.info('- Keystore path: $projectKeystorePath');

    if (!Directory(projectKeystorePath).existsSync()) {
      logger.err('- Directory does not exist: $projectKeystorePath');
      throw Exception('Keystore directory not found.');
    }

    if ((Directory(projectKeystorePath).statSync().mode & 0x124) == 0) {
      logger.err('- No read permissions for file: $projectKeystorePath');
      throw Exception('Permission denied for Keystore directory.');
    }

    final firebaseServiceAccountPath = path.join(projectKeystorePath, _firebaseServiceAccountFileName);
    final firebaseServiceAccount = File(firebaseServiceAccountPath).readAsStringSync().toMap();

    logger
      ..info('- Firebase service account path: $firebaseServiceAccountPath')
      ..info('- Firebase service account: $firebaseServiceAccount');

    final firebaseAccountId = firebaseServiceAccount[projectIdField] as String;

    return AppConfigureContext(
      workingDirectoryPath: workingDirectoryPath,
      projectKeystorePath: projectKeystorePath,
      bundleIdAndroid: bundleIdAndroid,
      bundleIdIos: bundleIdIos,
      firebaseAccountId: firebaseAccountId,
      firebaseServiceAccountPath: firebaseServiceAccountPath,
    );
  }

  final String workingDirectoryPath;
  final String projectKeystorePath;
  final String bundleIdAndroid;
  final String bundleIdIos;
  final String firebaseAccountId;
  final String firebaseServiceAccountPath;
}
