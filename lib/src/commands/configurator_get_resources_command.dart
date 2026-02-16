import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:data/datasource/datasource.dart';

import 'package:webtrit_phone_tools/src/utils/utils.dart';

import 'constants.dart';

const _argApplicationId = 'applicationId';
const _argToken = 'token';
const _argKeystoresPath = 'keystores-path';
const _argCacheSessionDataPath = 'cache-session-data-path';

const _paramDirectory = '<directory>';
const _descDirectory = '$_paramDirectory (optional)';

class ConfiguratorGetResourcesCommand extends Command<int> {
  ConfiguratorGetResourcesCommand({
    required Logger logger,
    required HttpClient httpClient,
    required ConfiguratorBackandDatasource datasource,
  })  : _logger = logger,
        _httpClient = httpClient,
        _datasource = datasource {
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
  String get description {
    final buffer = StringBuffer()
      ..writeln('Get resources to customize application')
      ..write(parameterIndent)
      ..write(_descDirectory)
      ..write(parameterDelimiter)
      ..writeln('Specify the directory for creating keystore and metadata files.')
      ..write(' ' * (parameterIndent.length + _descDirectory.length + parameterDelimiter.length))
      ..write('Defaults to the current working directory if not provided.');
    return buffer.toString();
  }

  @override
  String get invocation => '${super.invocation} [$_paramDirectory]';

  final Logger _logger;
  final HttpClient _httpClient;
  final ConfiguratorBackandDatasource _datasource;

  @override
  Future<int> run() async {
    try {
      final context = _buildContext();

      _datasource.addInterceptor(HeadersInterceptor(context.authHeader));

      final (application, theme) = await ApplicationDataFetcher(
        datasource: _datasource,
        logger: _logger,
      ).fetch(
        applicationId: context.applicationId,
        authHeader: context.authHeader,
      );

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

      final assetProcessor = AssetProcessor(
        httpClient: _httpClient,
        datasource: _datasource,
        logger: _logger,
      );

      final splashInfo = await assetProcessor.processSplashAssets(
        applicationId: context.applicationId,
        themeId: theme.id!,
        resolvePath: context.resolvePath,
      );

      final launchIcons = await assetProcessor.processLaunchIcons(
        applicationId: context.applicationId,
        themeId: theme.id!,
        resolvePath: context.resolvePath,
      );

      await ThemeConfigProcessor(
        httpClient: _httpClient,
        datasource: _datasource,
        logger: _logger,
      ).process(
        applicationId: context.applicationId,
        themeId: theme.id!,
        resolvePath: context.resolvePath,
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
      authHeader: {'Authorization': 'Bearer $token'},
      cachePathArg: argResults![_argCacheSessionDataPath] as String?,
    );
  }
}
