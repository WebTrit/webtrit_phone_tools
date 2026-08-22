import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/configurator/configurator.dart';

import 'package:webtrit_phone_tools/src/utils/utils.dart';

import 'models/models.dart';
import 'processors/processors.dart';
import 'runners/external_generator_runner.dart';
import 'services/services.dart';

const _argApplicationId = 'applicationId';
const _argToken = 'token';
const _argKeystoresPath = 'keystores-path';
const _argCacheSessionDataPath = 'cache-session-data-path';

const _paramDirectory = '<directory>';
const _descDirectory = '$_paramDirectory (optional)';

class AppResourcesGetCommand extends Command<int> {
  AppResourcesGetCommand({
    required Logger logger,
    required HttpClient httpClient,
    required ConfiguratorClient client,
  })  : _logger = logger,
        _httpClient = httpClient,
        _client = client {
    argParser
      ..addOption(
        _argApplicationId,
        help: 'Configurator application id.',
        mandatory: true,
      )
      ..addOption(
        _argToken,
        help: 'JWT token for configurator API.',
        mandatory: true,
      )
      ..addOption(
        _argKeystoresPath,
        help: "Path to the project's keystore folder.",
        mandatory: true,
      )
      ..addOption(
        _argCacheSessionDataPath,
        help: 'Path to file which cache temporarily stores user session data.',
      );
  }

  @override
  String get name => 'configurator-resources';

  @override
  String get description => CommandHelpFormatter.formatDescription(
        title: 'Get resources to customize application',
        parameter: _descDirectory,
        description: 'Specify the directory for creating keystore and metadata files.',
        note: 'Defaults to the current working directory if not provided.',
      );

  @override
  String get invocation => '${super.invocation} [$_paramDirectory]';

  final Logger _logger;
  final HttpClient _httpClient;
  final ConfiguratorClient _client;

  @override
  Future<int> run() async {
    try {
      final context = _buildContext();

      // The token the run was given travels with every read from here on.
      final client = _client.withHeaders(context.authHeader);

      final (application, theme) = await ApplicationDataFetcher(
        client: client,
        logger: _logger,
      ).fetch(applicationId: context.applicationId);

      await CertificateProcessor(logger: _logger).process(
        projectKeystorePath: context.projectKeystorePath,
        resolvePath: context.resolvePath,
      );

      await TranslationProcessor(
        httpClient: _httpClient,
        logger: _logger,
      ).process(
        applicationId: context.applicationId,
        resolvePath: context.resolvePath,
      );

      final localConfigProcessor = LocalConfigProcessor(logger: _logger);

      await localConfigProcessor.writeBuildCache(
        application: application,
        projectKeystorePath: context.projectKeystorePath,
        cachePathArg: context.cachePathArg,
        resolvePath: context.resolvePath,
      );

      // What the app IS comes first: its configuration, its embeds, its theme
      // and its fonts. What the app LOOKS like on the way in - the splash and
      // the launcher icons - comes after, and cannot take the rest with it.
      // It used to be the other way round, and a single refused image answer
      // left a brand with none of its settings at all.
      await ThemeConfigProcessor(
        httpClient: _httpClient,
        client: client,
        logger: _logger,
      ).process(
        applicationId: context.applicationId,
        themeId: theme.id!,
        resolvePath: context.resolvePath,
      );

      final assetProcessor = AssetProcessor(
        httpClient: _httpClient,
        client: client,
        logger: _logger,
      );

      final splashInfo = await _imagesOrWarning(
        'splash screen',
        'the app will be built with the stock WebTrit splash',
        () => assetProcessor.processSplashAssets(
          applicationId: context.applicationId,
          themeId: theme.id!,
          resolvePath: context.resolvePath,
        ),
      );

      final launchIcons = await _imagesOrWarning(
        'launcher icons',
        'the app will be built with the stock WebTrit icons',
        () => assetProcessor.processLaunchIcons(
          applicationId: context.applicationId,
          themeId: theme.id!,
          resolvePath: context.resolvePath,
        ),
      );

      await ExternalGeneratorRunner(logger: _logger).runGenerators(
        workingDirectoryPath: context.workingDirectoryPath,
        application: application,
        splashInfo: splashInfo,
        launchIcons: launchIcons,
      );

      await localConfigProcessor.writeEnvironmentConfig(
        application: application,
        projectKeystorePath: context.projectKeystorePath,
        resolvePath: context.resolvePath,
      );

      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.usage.code;
    }
  }

  /// Runs one image step. A refusal here is said out loud and named for what
  /// the brand loses, and the run carries on: an app with someone else's splash
  /// is recoverable and visible, an app with none of its own settings is not.
  Future<T?> _imagesOrWarning<T>(
    String what,
    String consequence,
    Future<T> Function() step,
  ) async {
    try {
      return await step();
    } catch (e, s) {
      _logger
        ..err('Could not fetch the $what: $e')
        ..err('  -> $consequence.')
        ..err('  -> Everything else was generated. Fix this and run again.')
        ..detail('$s');
      return null;
    }
  }

  CommandContext _buildContext() {
    final rest = argResults!.rest;

    final workingDirectoryPath = rest.isEmpty
        ? Directory.current.path
        : rest.length == 1
            ? rest[0]
            : throw UsageException('Only one "$_paramDirectory" parameter can be passed.', usage);

    final applicationId = argResults![_argApplicationId] as String;
    final token = argResults![_argToken] as String;

    if (applicationId.isEmpty || token.isEmpty) {
      throw UsageException('Application ID and Token must not be empty.', usage);
    }

    final keystoreArg = argResults![_argKeystoresPath] as String;

    final keystoreDirPath = path.isAbsolute(keystoreArg)
        ? path.normalize(keystoreArg)
        : path.normalize(path.join(workingDirectoryPath, keystoreArg));

    final keystoreDir = Directory(keystoreDirPath);

    if (!keystoreDir.existsSync()) {
      _logger.err('Keystores directory path does not exist: ${keystoreDir.path}');
      throw UsageException('Invalid keystore path', usage);
    }

    final projectKeystoreDir = Directory(path.join(keystoreDir.path, applicationId));
    if (!projectKeystoreDir.existsSync()) {
      _logger.err('Project keystore directory path does not exist: ${projectKeystoreDir.path}');
      throw UsageException('Invalid project keystore path', usage);
    }

    _logger.info('- Project keystore directory: ${projectKeystoreDir.path}');

    return CommandContext(
      workingDirectoryPath: workingDirectoryPath,
      applicationId: applicationId,
      projectKeystorePath: projectKeystoreDir.path,
      authHeader: {
        'Authorization': 'Bearer $token',
        // Which era is writing: see readPhoneVersion.
        if (readPhoneVersion(workingDirectoryPath) case final version?) 'X-Phone-Version': version,
      },
      cachePathArg: argResults![_argCacheSessionDataPath] as String?,
    );
  }
}
