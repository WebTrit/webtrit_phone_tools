import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/utils/utils.dart';

import 'constants/constants.dart';
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
  })  : _logger = logger,
        _httpClient = httpClient {
    argParser
      ..addOption(
        _argApplicationId,
        help: 'Configurator application id.',
        mandatory: true,
      )
      ..addOption(
        _argToken,
        help: 'A signed-in token, or an administrator-minted build key (wtc_...).',
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

  @override
  Future<int> run() async {
    try {
      final context = _buildContext();

      // One request. The service chose the theme, resolved the appearances,
      // pointed every picture reference at the file it will live in and named
      // the path each document belongs to - so what follows is writing, not
      // deciding.
      final bundle = BuildBundle.fromJson(
        await _httpClient.getBuildBundle(context.applicationId, headers: context.authHeader),
      );
      _logger.info('- Theme: ${bundle.themeId}');

      final writer = BundleWriter(httpClient: _httpClient, logger: _logger);

      // What the app IS comes first: its configuration and the pictures it
      // points at. What it LOOKS like on the way in - the splash and the
      // launcher icons - comes after, and cannot take the rest with it. It used
      // to be the other way round, and a single refused image answer left a
      // brand with none of its settings at all.
      await writer.writeFiles(bundle.files, context.resolvePath);
      await writer.downloadAssets(bundle.assets, context.resolvePath);

      await CertificateProcessor(logger: _logger).process(
        projectKeystorePath: context.projectKeystorePath,
        resolvePath: context.resolvePath,
      );

      await _orDegraded<void>(
        'translations',
        'the app will be built with the translations that ship in it',
        () => TranslationProcessor(
          httpClient: _httpClient,
          logger: _logger,
        ).process(
          applicationId: context.applicationId,
          chosen: bundle.locales,
          resolvePath: context.resolvePath,
          headers: context.authHeader,
        ),
      );

      final localConfigProcessor = LocalConfigProcessor(logger: _logger);

      await localConfigProcessor.writeBuildCache(
        application: bundle.application,
        projectKeystorePath: context.projectKeystorePath,
        cachePathArg: context.cachePathArg,
        resolvePath: context.resolvePath,
      );

      // The typeface the theme asks for. It reaches Google Fonts, so it is one
      // more thing that can refuse without costing the brand its settings.
      await _orDegraded<void>(
        'font',
        'the app will be built with the stock typeface',
        () => FontAssetProcessor(logger: _logger).process(
          lightConfig: _widgetConfig(bundle, assetWidgetsLightConfig),
          darkConfig: _widgetConfig(bundle, assetWidgetsDarkConfig),
          resolvePath: context.resolvePath,
        ),
      );

      await _orDegraded<void>(
        'splash screen',
        'the app will be built with the stock WebTrit splash',
        () => writer.downloadBrandImages(bundle.brandImages.splash, 'splash screen', context.resolvePath),
      );

      await _orDegraded<void>(
        'launcher icons',
        'the app will be built with the stock WebTrit icons',
        () => writer.downloadBrandImages(bundle.brandImages.launcher, 'launcher icon', context.resolvePath),
      );

      await ExternalGeneratorRunner(logger: _logger).runGenerators(
        workingDirectoryPath: context.workingDirectoryPath,
        application: bundle.application,
        brandImages: bundle.brandImages,
      );

      await localConfigProcessor.writeEnvironmentConfig(
        application: bundle.application,
        projectKeystorePath: context.projectKeystorePath,
        resolvePath: context.resolvePath,
      );

      if (_degraded.isNotEmpty) {
        _logger
          ..err('')
          ..err('Everything else was generated, but ${_degraded.length} step(s) failed:');
        for (final failure in _degraded) {
          _logger.err('  - ${failure.what}: ${failure.consequence}');
        }
        _logger.err('Fix this and run again; this build is not the one the brand asked for.');
        return ExitCode.software.code;
      }

      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.usage.code;
    }
  }

  /// The widget appearance the bundle carries, as a plain map. Absent means the
  /// service sent no such file, which the font step reads as "nothing to do".
  Map<String, dynamic> _widgetConfig(BuildBundle bundle, String path) {
    final document = bundle.files[path];
    return document is Map<String, dynamic> ? document : const {};
  }

  /// Runs one step that a brand can live without. A refusal is said out loud
  /// and named for what the brand loses, and the run carries on: an app with
  /// someone else's splash is recoverable and visible, an app with none of its
  /// own settings is not.
  /// Runs a step that a build can survive without, and records it when it
  /// fails.
  ///
  /// Surviving is the point: a refused picture must cost the brand its picture
  /// and not its settings, so the run carries on and one run reports every
  /// problem rather than the first. What it must not do is finish successfully.
  /// It used to: the message said "Fix this and run again" while the command
  /// returned zero, so a pipeline that only reads the exit code shipped a build
  /// with WebTrit's icons, or with the strings that ship in the app instead of
  /// the brand's, and nothing downstream could tell.
  Future<T?> _orDegraded<T>(
    String what,
    String consequence,
    Future<T> Function() step,
  ) async {
    try {
      return await step();
    } catch (e, s) {
      _degraded.add(_Degradation(what, consequence, e));
      _logger
        ..err('Could not fetch the $what: $e')
        ..err('  -> $consequence.')
        ..detail('$s');
      return null;
    }
  }

  /// What the run could not fetch. Read once, at the end.
  final List<_Degradation> _degraded = [];

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
        ...credentialHeader(token),
        // Which era is writing: see readPhoneVersion.
        if (readPhoneVersion(workingDirectoryPath) case final version?) 'X-Phone-Version': version,
      },
      cachePathArg: argResults![_argCacheSessionDataPath] as String?,
    );
  }
}

/// One thing a run could not fetch, and what the build gets instead.
class _Degradation {
  const _Degradation(this.what, this.consequence, this.error);

  final String what;
  final String consequence;
  final Object error;
}
