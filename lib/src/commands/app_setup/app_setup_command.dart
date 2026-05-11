import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/utils/utils.dart';

import 'models/models.dart';
import 'runners/runners.dart';

const _argPlatform = 'platform';
const _argKeystorePath = 'keystore-path';
const _argCacheSessionDataPath = 'cache-session-data-path';
const _paramDirectory = '<directory>';

class AppSetupCommand extends Command<int> {
  AppSetupCommand({
    required Logger logger,
    FirebaseSetupRunner? firebaseSetupRunner,
  })  : _logger = logger,
        _firebaseSetupRunner = firebaseSetupRunner {
    argParser
      ..addMultiOption(
        _argPlatform,
        help: 'Target platform(s) for setup. Can be specified multiple times.',
        allowed: ['ios', 'android'],
      )
      ..addOption(
        _argKeystorePath,
        help: 'Path to the application keystore directory (absolute, or relative to the phone project directory). '
            'Must be provided explicitly — do not rely on the cached path, '
            'which may reference a different OS.',
        mandatory: true,
      )
      ..addOption(
        _argCacheSessionDataPath,
        help: 'Path to cache_session_data.json produced by configurator-resources. '
            'Defaults to cache_session_data.json in the working directory.',
      );
  }

  @override
  String get name => 'configurator-setup';

  @override
  String get description => CommandHelpFormatter.formatDescription(
        title: 'Run platform-specific setup for the application build',
        parameter: _paramDirectory,
        description: 'Specify the phone project directory.',
        note: 'Defaults to the current working directory if not provided. '
            'Runs flutterfire configure for the given platform, producing the '
            'platform Firebase config file (GoogleService-Info.plist for iOS, '
            'google-services.json for Android) and registering any required '
            'build-phase hooks.',
      );

  @override
  String get invocation => '${super.invocation} [$_paramDirectory]';

  final Logger _logger;
  final FirebaseSetupRunner? _firebaseSetupRunner;

  @override
  Future<int> run() async {
    try {
      final context = AppSetupContext.fromArgs(argResults!, _logger);

      await (_firebaseSetupRunner ?? FirebaseSetupRunner(logger: _logger)).configure(context);

      _logger.success('✓ configurator-setup completed for ${context.platforms.map((p) => p.name).join(', ')}');
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
