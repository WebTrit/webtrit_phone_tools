import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:data/datasource/datasource.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';

import 'package:webtrit_phone_tools/src/commands/commands.dart';
import 'package:webtrit_phone_tools/src/version.dart';

import 'commands/constants.dart';
import 'utils/utils.dart';

const executableName = 'webtrit_phone_tools';
const packageName = 'webtrit_phone_tools';
const description = 'WebTrit Phone CLI tools';

/// {@template webtrit_phone_tools_command_runner}
/// A [CommandRunner] for the CLI.
///
/// ```
/// $ webtrit_phone_tools --version
/// ```
/// {@endtemplate}
class WebtritPhoneToolsCommandRunner extends CompletionCommandRunner<int> {
  /// {@macro webtrit_phone_tools_command_runner}
  WebtritPhoneToolsCommandRunner({
    Logger? logger,
    ConfiguratorBackandDatasource? datasource,
    HttpClient? httpClient,
    KeystoreReadmeUpdater? keystoreReadmeUpdater,
    PubUpdater? pubUpdater,
  })  : _logger = logger ?? Logger(),
        _httpClient = httpClient ?? HttpClient(configuratorApiUrl, Logger()),
        _datasource = datasource ??
            ConfiguratorBackandDatasource(
              Dio(BaseOptions(
                baseUrl: 'https://us-central1-webtrit-configurator.cloudfunctions.net/api/v1',
                // headers: {'Authorization': 'Bearer $configuratorToken'},
              )),
              UnauthorizedInterceptor(),
            ),
        _keystoreReadmeUpdater = keystoreReadmeUpdater ?? KeystoreReadmeUpdater(Logger()),
        _pubUpdater = pubUpdater ?? PubUpdater(),
        super(executableName, description) {
    // Add root options and flags
    argParser
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the current version.',
      )
      ..addFlag(
        'verbose',
        help: 'Noisy logging, including all shell commands executed.',
      );

    // Add sub commands
    addCommand(ConfiguratorGetResourcesCommand(
      logger: _logger,
      httpClient: _httpClient,
      datasource: _datasource,
    ));
    addCommand(ConfiguratorGenerateCommand(logger: _logger));
    addCommand(KeystoreInitCommand(
      logger: _logger,
      httpClient: _httpClient,
      keystoreReadmeUpdater: _keystoreReadmeUpdater,
    ));
    addCommand(KeystoreGenerateCommand(logger: _logger));
    addCommand(KeystoreCommitCommand(logger: _logger));
    addCommand(KeystoreVerifyCommand(logger: _logger));
    addCommand(AssetlinksGenerateCommand(logger: _logger));
    addCommand(UpdateCommand(logger: _logger, pubUpdater: _pubUpdater));
  }

  @override
  void printUsage() => _logger.info(usage);

  final Logger _logger;
  final ConfiguratorBackandDatasource _datasource;
  final HttpClient _httpClient;

  final KeystoreReadmeUpdater _keystoreReadmeUpdater;
  final PubUpdater _pubUpdater;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final topLevelResults = parse(args);
      if (topLevelResults['verbose'] == true) {
        _logger.level = Level.verbose;
      }
      return await runCommand(topLevelResults) ?? ExitCode.success.code;
    } on FormatException catch (e, stackTrace) {
      // On format errors, show the commands error message, root usage and
      // exit with an error code
      _logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      // On usage errors, show the commands usage message and
      // exit with an error code
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    // Fast track completion command
    if (topLevelResults.command?.name == 'completion') {
      await super.runCommand(topLevelResults);
      return ExitCode.success.code;
    }

    // Verbose logs
    _logger
      ..detail('Argument information:')
      ..detail('  Top level options:');
    for (final option in topLevelResults.options) {
      if (topLevelResults.wasParsed(option)) {
        _logger.detail('  - $option: ${topLevelResults[option]}');
      }
    }
    if (topLevelResults.command != null) {
      final commandResult = topLevelResults.command!;
      _logger
        ..detail('  Command: ${commandResult.name}')
        ..detail('    Command options:');
      for (final option in commandResult.options) {
        if (commandResult.wasParsed(option)) {
          _logger.detail('    - $option: ${commandResult[option]}');
        }
      }
    }

    // Run the command or show version
    final int? exitCode;
    if (topLevelResults['version'] == true) {
      _logger.info(packageVersion);
      exitCode = ExitCode.success.code;
    } else {
      exitCode = await super.runCommand(topLevelResults);
    }

    // Check for updates
    if (topLevelResults.command?.name != UpdateCommand.commandName) {
      await _checkForUpdates();
    }

    return exitCode;
  }

  /// Checks if the current version (set by the build runner on the
  /// version.dart file) is the most recent one. If not, show a prompt to the
  /// user.
  Future<void> _checkForUpdates() async {
    try {
      final latestVersion = await _pubUpdater.getLatestVersion(packageName);
      final isUpToDate = packageVersion == latestVersion;
      if (!isUpToDate) {
        _logger
          ..info('')
          ..info(
            '''
${lightYellow.wrap('Update available!')} ${lightCyan.wrap(packageVersion)} \u2192 ${lightCyan.wrap(latestVersion)}
Run ${lightCyan.wrap('$executableName update')} to update''',
          );
      }
    } catch (_) {}
  }
}
