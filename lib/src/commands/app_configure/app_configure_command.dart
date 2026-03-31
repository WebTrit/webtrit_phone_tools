import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/utils/utils.dart';

import 'models/app_configure_context.dart';
import 'runners/firebase_runner.dart';
import 'runners/flutter_runner.dart';
import 'runners/make_runner.dart';

const _bundleIdAndroid = 'bundleIdAndroid';
const _bundleIdIos = 'bundleIdIos';
const _keystorePath = 'keystore-path';
const _cacheSessionDataPath = 'cache-session-data-path';
const _directoryParameterName = '<directory>';

class AppConfigureCommand extends Command<int> {
  AppConfigureCommand({
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
  String get description => CommandHelpFormatter.formatDescription(
        title: 'Generate resources for customize application',
        parameter: _directoryParameterName,
        description: 'Specify the directory for configuring the application.',
        note: 'Defaults to the current working directory if not provided.',
      );

  final Logger _logger;

  @override
  Future<int> run() async {
    try {
      final context = AppConfigureContext.fromArgs(argResults!, _logger);

      _logger
        ..info('- Platform identifier android: ${context.bundleIdAndroid}')
        ..info('- Platform identifier ios: ${context.bundleIdIos}')
        ..info('- Scripts working directory: ${context.workingDirectoryPath}')
        ..info('- Service account path: ${context.firebaseServiceAccountPath}');

      final flutterRunner = FlutterRunner(logger: _logger);
      final makeRunner = MakeRunner(logger: _logger);
      final firebaseRunner = FirebaseRunner(logger: _logger);

      // Setup dependencies for the proper functioning of the configuration script
      await flutterRunner.setupDependencies(context.workingDirectoryPath);

      // Configure firebase for all supported platforms
      await firebaseRunner.configure(context);

      // Configure launch icons for all supported platforms
      await makeRunner.configureLaunchIcons(context.workingDirectoryPath);

      // Configure splash screen for all supported platforms
      await makeRunner.configureSplash(context.workingDirectoryPath);

      // Configure platforms bundle id and package name
      await makeRunner.configurePlatformIdentifiers(context.workingDirectoryPath);

      // Configure localization for support languages
      await flutterRunner.configureLocalization(context.workingDirectoryPath);

      // Configure assets, especially if they are removed unexpectedly
      await flutterRunner.configureAssets(context.workingDirectoryPath);

      return ExitCode.success.code;
    } on UsageException catch (e) {
      _logger.err(e.message);
      return ExitCode.usage.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.data.code;
    }
  }
}
