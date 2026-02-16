import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:data/datasource/datasource.dart';
import 'package:data/dto/dto.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

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
      final args = _parseArguments();
      _datasource.addInterceptor(HeadersInterceptor(args.authHeader));

      final projectKeystorePath = _validateDirectories(
        workingDirectoryPath: args.workingDirectoryPath,
        applicationId: args.applicationId,
      );
      if (projectKeystorePath == null) return ExitCode.data.code;

      final context = CommandContext(
        workingDirectoryPath: args.workingDirectoryPath,
        applicationId: args.applicationId,
        projectKeystorePath: projectKeystorePath,
        authHeader: args.authHeader,
      );

      final (application, theme) = await _fetchApplicationData(context);

      await _processCertificates(context);

      await TranslationProcessor(
        httpClient: _httpClient,
        logger: _logger,
      ).process(
        applicationId: context.applicationId,
        resolvePath: context.resolvePath,
      );

      await _writeBuildCache(context, application);

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

      await _runExternalGenerators(
        context: context,
        application: application,
        splashInfo: splashInfo,
        launchIcons: launchIcons,
      );

      await _configureEnvironment(context, application);

      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.usage.code;
    }
  }

  ({String workingDirectoryPath, String applicationId, Map<String, String> authHeader}) _parseArguments() {
    String workingDirectoryPath;
    final rest = argResults!.rest;

    if (rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (rest.length == 1) {
      workingDirectoryPath = rest[0];
    } else {
      throw UsageException('Only one "$_paramDirectory" parameter can be passed.', usage);
    }

    final applicationId = argResults![_argApplicationId] as String;
    final token = argResults![_argToken] as String;

    if (applicationId.isEmpty || token.isEmpty) {
      throw UsageException('Application ID and Token must not be empty.', usage);
    }

    return (
      workingDirectoryPath: workingDirectoryPath,
      applicationId: applicationId,
      authHeader: {'Authorization': 'Bearer $token'},
    );
  }

  String? _validateDirectories({
    required String workingDirectoryPath,
    required String applicationId,
  }) {
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

    final cachePathArg = argResults![_argCacheSessionDataPath] as String?;
    final cachePath = cachePathArg ?? defaultCacheSessionDataPath;
    final cacheDir = Directory(path.dirname(cachePath));

    if (cacheDir.path != '.' && !cacheDir.existsSync()) {
      _logger.err('Cache directory does not exist: ${cacheDir.path}');
      return null;
    }

    return projectKeystoreDir.path;
  }

  Future<(ApplicationDTO, ThemeDTO)> _fetchApplicationData(CommandContext context) async {
    final application = await _datasource.getApplication(
      applicationId: context.applicationId,
      headers: context.authHeader,
    );

    if (application.theme == null) {
      throw Exception('Application ${context.applicationId} does not have a default theme.');
    }

    final theme = await _datasource.getTheme(
      applicationId: context.applicationId,
      themeId: application.theme!,
      headers: context.authHeader,
    );

    _logger.info('- Fetched theme: ${theme.id}');
    return (application, theme);
  }

  Future<void> _processCertificates(CommandContext context) async {
    final sslDir = Directory(path.join(context.projectKeystorePath, kSSLCertificatePath));

    if (!sslDir.existsSync()) {
      _logger.warn('- Project SSL certificates directory does not exist.');
      return;
    }

    _logger.info('- Processing SSL certificates...');
    final targetDir = Directory(context.resolvePath(assetSSLCertificate));
    if (!targetDir.existsSync()) await targetDir.create(recursive: true);

    await for (final entity in sslDir.list()) {
      if (entity is! File) continue;

      final newPath = path.join(targetDir.path, path.basename(entity.path));
      await entity.copy(newPath);
      _logger.info('  Copy: ${entity.path} -> $newPath');
    }

    final credsFile = File(path.join(context.projectKeystorePath, kSSLCertificateCredentialPath));
    if (credsFile.existsSync()) {
      await credsFile.copy(path.join(targetDir.path, assetSSLCertificateCredentials));
      _logger.info('  Copy: Credentials file.');
    }
  }

  Future<void> _writeBuildCache(CommandContext context, ApplicationDTO application) async {
    final config = AppConfigFactory.createBuildCacheConfig(application, context.projectKeystorePath);

    final cachePathArg = argResults![_argCacheSessionDataPath] as String? ?? defaultCacheSessionDataPath;
    await writeJsonToFile(context.resolvePath(cachePathArg), config, logger: _logger);
  }

  Future<void> _runExternalGenerators({
    required CommandContext context,
    required ApplicationDTO application,
    required SplashAssetDto splashInfo,
    required LaunchAssetsEnvelopeDto launchIcons,
  }) async {
    final launchBgColor = launchIcons.entity.source?.backgroundColorHex;

    if (launchBgColor != null) {
      _logger.info('- Running: generate-launcher-icons-config');
      final env = AppConfigFactory.createLauncherIconsEnv(launchBgColor);
      await _runMakeCommand(context, 'generate-launcher-icons-config', env);
    } else {
      _logger.warn('Skipping launcher generation: backgroundColorHex is null.');
    }

    final splashBgColor = splashInfo.source?.backgroundColorHex;
    if (splashBgColor != null) {
      _logger.info('- Running: generate-native-splash-config');
      final env = AppConfigFactory.createNativeSplashEnv(splashBgColor);
      await _runMakeCommand(context, 'generate-native-splash-config', env);
    } else {
      _logger.warn('Skipping splash generation: backgroundColorHex is null.');
    }

    _logger.info('- Running: generate-package-config');
    final packageEnv = AppConfigFactory.createPackageConfigEnv(application);
    await _runMakeCommand(context, 'generate-package-config', packageEnv);
  }

  Future<void> _configureEnvironment(CommandContext context, ApplicationDTO application) async {
    final env = AppConfigFactory.createDartDefineEnv(application, context.projectKeystorePath);

    final file = File(context.resolvePath(configureDartDefinePath));
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }

    await file.writeAsString(jsonEncode(env));
    _logger.success('✓ Environment config written to ${file.path}');
  }

  Future<void> _runMakeCommand(CommandContext context, String target, Map<String, String> environment) async {
    _logger.info('Running generator: $target...');

    final process = await Process.start(
      'make',
      [target],
      workingDirectory: context.workingDirectoryPath,
      runInShell: true,
      environment: environment,
    );

    final stdoutFuture = process.stdout.transform(utf8.decoder).forEach((data) => _logger.detail(data.trim()));
    final stderrFuture = process.stderr.transform(utf8.decoder).forEach((data) => _logger.warn(data.trim()));

    await Future.wait([stdoutFuture, stderrFuture]);
    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw Exception('Command "make $target" failed with exit code $exitCode');
    }
    _logger.success('✓ Generator $target completed');
  }
}
