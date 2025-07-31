import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';

const _bundleIdAndroid = 'bundleIdAndroid';
const _bundleIdIos = 'bundleIdIos';
const _keystorePath = 'keystore-path';
const _cacheSessionDataPath = 'cache-session-data-path';

const _directoryParameterName = '<directory>';
const _firebaseServiceAccountFileName = 'build/google-play-service-account.json';

class ConfiguratorGenerateCommand extends Command<int> {
  ConfiguratorGenerateCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        _keystorePath,
        help: "Path to the project's keystore folder.",
      )
      ..addOption(
        _bundleIdAndroid,
        help: 'Android application identifier.',
      )
      ..addOption(
        _bundleIdIos,
        help: 'iOS application identifier.',
      )
      ..addOption(
        _cacheSessionDataPath,
        help: 'Path to file which cache temporarily stores user session data to enhance performance '
            'and maintain state across different processes.',
      );
  }

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

  late String workingDirectoryPath;

  @override
  Future<int> run() async {
    final commandArgResults = argResults!;

    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      _logger.err('Only one "$_directoryParameterName" parameter can be passed.');
      return ExitCode.usage.code;
    }

    final cacheSessionDataPath = (commandArgResults[_cacheSessionDataPath] as String?) ?? defaultCacheSessionDataPath;

    if (!File(cacheSessionDataPath).existsSync()) {
      _logger.err(
          '- The default cache_session_data.json file was not used, generated, or prepared before running this script, '
          'or the custom path to cache session data was not provided correctly.');
      return ExitCode.data.code;
    }

    final cacheSessionData = File(_workingDirectory(relativePath: cacheSessionDataPath)).readAsStringSync().toMap();

    final projectKeystorePathArg = commandArgResults[_keystorePath] as String?;
    final projectKeystorePathBuildConfig = cacheSessionData[keystorePathField] as String?;
    final projectKeystorePath = projectKeystorePathArg ?? projectKeystorePathBuildConfig ?? '';

    final bundleIdAndroid =
        (commandArgResults[_bundleIdAndroid] as String?) ?? cacheSessionData[bundleIdAndroidField] as String?;

    if ((bundleIdAndroid ?? '').isEmpty) {
      _logger.err('Option "$_bundleIdAndroid" can not be empty.');
      return ExitCode.usage.code;
    }

    final bundleIdIos = (commandArgResults[_bundleIdIos] as String?) ?? cacheSessionData[bundleIdIosField] as String?;

    if ((bundleIdIos ?? '').isEmpty) {
      _logger.err('Option "$_bundleIdIos" can not be empty.');
      return ExitCode.usage.code;
    }

    if (projectKeystorePath.isEmpty) {
      _logger.err(
        'The option $_keystorePath cannot be empty and must be provided as a parameter or through $defaultCacheSessionDataPath',
      );
      return ExitCode.usage.code;
    }

    _logger.info('- Keystore path: $projectKeystorePath');

    if (!Directory(projectKeystorePath).existsSync()) {
      _logger.err('- Directory does not exist: $projectKeystorePath');
      return ExitCode.data.code;
    }

    if ((Directory(projectKeystorePath).statSync().mode & 0x124) == 0) {
      _logger.err('- No read permissions for file: $projectKeystorePath');
      return ExitCode.data.code;
    }

    final firebaseServiceAccountPath = path.join(projectKeystorePath, _firebaseServiceAccountFileName);
    final firebaseServiceAccount = File(firebaseServiceAccountPath).readAsStringSync().toMap();
    _logger.info('- Firebase service account path: $firebaseServiceAccountPath');
    _logger.info('- Firebase service account: $firebaseServiceAccount');
    final firebaseAccountId = firebaseServiceAccount[projectIdField] as String;

    final workingDirectory = _workingDirectory();

    // Setup dependencies for the proper functioning of the configuration script
    await _setupDependencies(workingDirectory);

    _logger
      ..info('- Platform identifier android: $bundleIdAndroid')
      ..info('- Platform identifier ios: $bundleIdIos')
      ..info('- Scripts working directory: $workingDirectory')
      ..info('- Service account path: $firebaseServiceAccountPath');

    // Configure firebase for all supported platforms
    await _configureFirebase(firebaseAccountId, bundleIdAndroid, bundleIdIos, firebaseServiceAccountPath);

    // Configure launch icons for all supported platforms
    await _configureLaunchIcons(workingDirectory);

    // Configure splash screen for all supported platforms
    await _configureSplash(workingDirectory);

    // Configure platforms bundle id and package name
    await _configurePlatformsIdentifiers(workingDirectory);

    // Configure localization for support languages
    await _configureLocalization(workingDirectory);

    // Configure assets, especially if they are removed unexpectedly
    await _configureAssets(workingDirectory);

    return ExitCode.success.code;
  }

  Future<void> _setupDependencies(String workingDirectory) async {
    final flutterGenDependencyProcess = await Process.run(
      'dart',
      ['pub', 'global', 'activate', 'flutter_gen'],
      workingDirectory: workingDirectory,
    );

    _logger
      ..info(flutterGenDependencyProcess.stdout.toString())
      ..err(flutterGenDependencyProcess.stderr.toString())
      ..info('Flutter gen generation finished with: ${flutterGenDependencyProcess.exitCode}');

    final firebaseDependencyProgress = await Process.run(
      'dart',
      ['pub', 'global', 'activate', 'flutterfire_cli'],
      workingDirectory: workingDirectory,
    );

    _logger
      ..info(firebaseDependencyProgress.stdout.toString())
      ..err(firebaseDependencyProgress.stderr.toString())
      ..info('Package renaming finished with: ${firebaseDependencyProgress.exitCode}');
  }

  Future<void> _configureFirebase(
    String firebaseAccountId,
    String? bundleIdAndroid,
    String? bundleIdIos,
    String firebaseServiceAccountPath,
  ) async {
    final workingDirectory = _workingDirectory();

    _logger
      ..info('Starting Firebase configuration for account: $firebaseAccountId')
      ..info('Working directory: $workingDirectory')
      ..info('Android bundle ID: $bundleIdAndroid')
      ..info('iOS bundle ID: $bundleIdIos')
      ..info('Service account path: $firebaseServiceAccountPath');

    try {
      _logger.info('Running flutterfire configure process, with service account: $firebaseServiceAccountPath');

      final process = await Process.start(
        'flutterfire',
        [
          'configure',
          '--yes',
          '--project=$firebaseAccountId',
          '--android-package-name=${bundleIdAndroid ?? ''}',
          '--ios-bundle-id=${bundleIdIos ?? ''}',
          '--service-account=$firebaseServiceAccountPath',
          '--platforms',
          'android,ios',
        ],
        workingDirectory: workingDirectory,
        runInShell: true,
      );

      process.stdout.transform(utf8.decoder).listen((data) {
        _logger.info('stdout: $data');
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        _logger.err('stderr: $data');
      });

      final exitCode = await process.exitCode;
      _logger.info('flutterfire finished with exit code: $exitCode');

      if (exitCode != 0) {
        _logger.err('Flutterfire process failed with exit code $exitCode. Please check the logs above for details.');
        throw Exception('Flutterfire configuration failed with exit code $exitCode');
      }
    } catch (e, stackTrace) {
      _logger
        ..err('Error during Firebase configuration: $e')
        ..err('StackTrace: $stackTrace');
      rethrow; // Rethrow to allow higher-level error handling if needed
    }
  }

  Future<void> _configureSplash(String workingDirectory) async {
    final packageRenameProcess = await Process.run(
      'make',
      ['generate-native-splash'],
      workingDirectory: workingDirectory,
    );

    _logger
      ..info(packageRenameProcess.stdout.toString())
      ..err(packageRenameProcess.stderr.toString())
      ..info('Package renaming finished with: ${packageRenameProcess.exitCode}');
  }

  Future<void> _configureLaunchIcons(String workingDirectory) async {
    final packageRenameProcess = await Process.run(
      'make',
      ['generate-launcher-icons'],
      workingDirectory: workingDirectory,
    );

    _logger
      ..info(packageRenameProcess.stdout.toString())
      ..err(packageRenameProcess.stderr.toString())
      ..info('Package renaming finished with: ${packageRenameProcess.exitCode}');
  }

  Future<void> _configureAssets(String workingDirectory) async {
    final flutterGenProcess = await Process.run(
      'fluttergen',
      [],
      workingDirectory: workingDirectory,
    );

    _logger
      ..info(flutterGenProcess.stdout.toString())
      ..err(flutterGenProcess.stderr.toString())
      ..info('Flutter gen finished with: ${flutterGenProcess.exitCode}');
  }

  Future<void> _configureLocalization(String workingDirectory) async {
    final flutterL10nProcess = await Process.run(
      'flutter',
      ['gen-l10n'],
      workingDirectory: workingDirectory,
    );

    _logger
      ..info(flutterL10nProcess.stdout.toString())
      ..err(flutterL10nProcess.stderr.toString())
      ..info('Localization generation finished with: ${flutterL10nProcess.exitCode}');
  }

  Future<void> _configurePlatformsIdentifiers(String workingDirectory) async {
    final packageRenameProcess = await Process.run(
      'make',
      ['rename-package'],
      workingDirectory: workingDirectory,
    );

    _logger
      ..info(packageRenameProcess.stdout.toString())
      ..err(packageRenameProcess.stderr.toString())
      ..info('Package renaming finished with: ${packageRenameProcess.exitCode}');
  }

  String _workingDirectory({String relativePath = ''}) {
    return path.normalize(path.join(workingDirectoryPath, relativePath));
  }
}
