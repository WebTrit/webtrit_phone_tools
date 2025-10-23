// lib/src/commands/configurator_get_resources_command.dart
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:data/datasource/datasource.dart';
import 'package:data/dto/dto.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:webtrit_appearance_theme/models/models.dart';
import 'package:yaml/yaml.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

// --- Припустимо, що в 'constants.dart' додано: ---
// const String assetAppConfigEmbeddedsPath = 'assets/cfg/app.config.embeddeds.json';
// ----------------------------------------------------

const _applicationId = 'applicationId';
const _token = 'token';
const _keystoresPath = 'keystores-path';
const _cacheSessionDataPath = 'cache-session-data-path';

const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

/// Fetches resources from Configurator and prepares local assets/configs.
/// Includes a generic JSON migration that:
/// - finds image URLs (http/https) across the config (ImageSource.uri, plain `uri`, any `*Url` key)
/// - downloads them to assets/images
/// - rewrites the config to `asset://assets/images/<file>`
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
        _applicationId,
        help: 'Configurator application id.',
        mandatory: true,
      )
      ..addOption(
        _token,
        help: 'JWT token for  configurator API.',
        mandatory: true,
      )
      ..addOption(
        _keystoresPath,
        help: "Path to the project's keystore folder.",
        mandatory: true,
      )
      ..addOption(
        _cacheSessionDataPath,
        help:
            'Path to file which cache temporarily stores user session data to enhance performance and maintain state across different processes.',
      );
  }

  @override
  String get name => 'configurator-resources';

  final HttpClient _httpClient;
  final ConfiguratorBackandDatasource _datasource;

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln('Get resources to customize application')
      ..write(parameterIndent)
      ..write(_directoryParameterDescriptionName)
      ..write(parameterDelimiter)
      ..writeln('Specify the directory for creating keystore and metadata files.')
      ..write(' ' * (parameterIndent.length + _directoryParameterDescriptionName.length + parameterDelimiter.length))
      ..write('Defaults to the current working directory if not provided.');
    return buffer.toString();
  }

  @override
  String get invocation => '${super.invocation} [$_directoryParameterName]';

  final Logger _logger;

  late String workingDirectoryPath;

  // --- Asset migration settings ---
  // Where files are saved on disk (relative to working dir)
  static const _imagesAssetDiskDir = 'assets/images';

  // How URIs are written into configs
  static const _imagesAssetLogicalPrefix = 'asset://assets/images';

  // Single-flight cache for URL → logical URI
  final Map<String, String> _assetCache = <String, String>{};

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

    final keystorePath = (commandArgResults[_keystoresPath] as String?) ?? '';
    if (keystorePath.isEmpty) {
      _logger.err('Option "$_keystoresPath" can not be empty.');
      return ExitCode.usage.code;
    }

    final paramCacheSessionDataPath = commandArgResults[_cacheSessionDataPath] as String?;
    final cacheSessionDataPath = paramCacheSessionDataPath ?? defaultCacheSessionDataPath;
    final cacheSessionDataDir = Directory(path.dirname(cacheSessionDataPath));

    final applicationId = commandArgResults[_applicationId] as String;
    if (applicationId.isEmpty) {
      _logger.err('Option "$_applicationId" can not be empty.');
      return ExitCode.usage.code;
    }

    final jwtToken = commandArgResults[_token] as String;
    final authHeader = {'Authorization': 'Bearer $jwtToken'};
    if (jwtToken.isEmpty) {
      _logger.err('Option "$_token" can not be empty.');
      return ExitCode.usage.code;
    }

    _datasource.addInterceptor(HeadersInterceptor(authHeader));

    final keystoreDirectoryPath = _workingDirectory(keystorePath);
    if (Directory(keystoreDirectoryPath).existsSync()) {
      _logger.info('- Keystores directory path: $keystoreDirectoryPath');
    } else {
      _logger.err('- Keystores directory path does not exist: $keystoreDirectoryPath');
      return ExitCode.usage.code;
    }

    final projectKeystoreDirectoryPath = path.join(keystoreDirectoryPath, applicationId);
    if (Directory(projectKeystoreDirectoryPath).existsSync()) {
      _logger.info('- Project keystore directory path: $projectKeystoreDirectoryPath');
    } else {
      _logger.err('- Project keystores directory path does not exist: $projectKeystoreDirectoryPath');
      return ExitCode.usage.code;
    }

    if (cacheSessionDataDir.path != '.' && !cacheSessionDataDir.existsSync()) {
      _logger.err('- The directory specified by $_cacheSessionDataPath does not exist.');
      return ExitCode.data.code;
    }

    late ApplicationDTO application;
    late ThemeDTO theme;

    try {
      application = await _datasource.getApplication(
        applicationId: applicationId,
        headers: authHeader,
      );
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    if (application.theme == null) {
      _logger.err('Application $applicationId does not have a default theme');
      return ExitCode.usage.code;
    }

    try {
      theme = await _datasource.getTheme(
        applicationId: applicationId,
        themeId: application.theme!,
        headers: authHeader,
      );
      _logger.info('- Fetched theme with id: ${theme.id} for application: $applicationId');
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    try {
      await _configureTranslations(applicationId);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    final projectSSlCertificatesDirectoryPath = path.join(projectKeystoreDirectoryPath, kSSLCertificatePath);
    final directorySSlCertificates = Directory(projectSSlCertificatesDirectoryPath);

    if (directorySSlCertificates.existsSync()) {
      _logger.info('- Project ssl certificates directory path: $projectSSlCertificatesDirectoryPath');

      await for (final entity in directorySSlCertificates.list()) {
        if (entity is File) {
          _logger.info('--- path: ${entity.path}');
          final certFile = File(entity.path);
          final directory = _workingDirectory(assetSSLCertificate);
          final newFilePath = path.join(directory, path.basename(certFile.path));
          _logger.info('--- copy: ${entity.path} to $newFilePath');

          await certFile.copy(newFilePath);

          final sslCertificatesCredentialsPath = path.join(projectKeystoreDirectoryPath, kSSLCertificateCredentialPath);
          final sslCertificatesCredentials = File(sslCertificatesCredentialsPath);

          if (sslCertificatesCredentials.existsSync()) {
            _logger.info('- Project ssl certificates directory credentials path exists');

            final newSSLCertificatesCredentials = path.join(directory, assetSSLCertificateCredentials);
            await sslCertificatesCredentials.copy(newSSLCertificatesCredentials);
          } else {
            _logger.info('- Project ssl certificates directory credentials path does not exist');
          }
        }
      }
    } else {
      _logger.warn('- Project ssl certificates directory path does not exist');
    }

    if (application.androidVersion?.buildName == null || application.androidVersion?.buildNumber == null) {
      _logger.err('Option "$_applicationId" cannot be empty: Android version build name or build number is missing.');
      return ExitCode.usage.code;
    }

    if (application.iosVersion?.buildName == null || application.iosVersion?.buildNumber == null) {
      _logger.err('Option "$_applicationId" cannot be empty: iOS version build name or build number is missing.');
      return ExitCode.usage.code;
    }

    // Prepare build cache
    final buildConfig = {
      bundleIdAndroidField: application.androidPlatformId,
      buildNameAndroidField: application.androidVersion?.buildName,
      buildNumberAndroidField: application.androidVersion?.buildNumber,
      bundleIdIosField: application.iosPlatformId,
      buildNameIOSField: application.iosVersion?.buildName,
      buildNumberIOSField: application.iosVersion?.buildNumber,
      keystorePathField: projectKeystoreDirectoryPath,
    };

    final buildConfigPath = _workingDirectory(cacheSessionDataPath);
    File(buildConfigPath).writeAsStringSync(buildConfig.toStringifyJson());
    _logger.success('✓ Written successfully to $buildConfigPath');

    // Splash & launch icons (kept as-is; these are special-cased)
    final splash = await _datasource.getSplashAsset(applicationId: applicationId, themeId: theme.id!);
    await _downloadAndSave(
      url: splash.splashUrl,
      relativePath: assetSplashIconPath,
      assetLabel: 'splash image',
    );

    final launchIcons = await _datasource.getLaunchAssetsByTheme(applicationId: applicationId, themeId: theme.id!);
    await _downloadAndSave(
      url: launchIcons.androidLegacyUrl,
      relativePath: assetLauncherAndroidIconPath,
      assetLabel: 'android launcher icon',
    );
    await _downloadAndSave(
      url: launchIcons.androidAdaptiveForegroundUrl,
      relativePath: assetLauncherIconAdaptiveForegroundPath,
      assetLabel: 'android adaptive foreground icon',
    );
    await _downloadAndSave(
      url: launchIcons.webUrl,
      relativePath: assetLauncherWebIconPath,
      assetLabel: 'web launcher icon',
    );
    await _downloadAndSave(
      url: launchIcons.iosUrl,
      relativePath: assetLauncherIosIconPath,
      assetLabel: 'ios launcher icon',
    );

    try {
      await _configureTheme(applicationId, theme.id!);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    _logger.info('- Prepare config for flutter_launcher_icons_template');

    if (launchIcons.entity.source?.backgroundColorHex != null) {
      await Process.start(
        'make',
        ['generate-launcher-icons-config'],
        workingDirectory: workingDirectoryPath,
        runInShell: true,
        environment: {
          'LAUNCHER_ICON_IMAGE_ANDROID': assetLauncherAndroidIconPath,
          'ICON_BACKGROUND_COLOR': splash.source?.backgroundColorHex?.toHex6WithHash() ?? '',
          'LAUNCHER_ICON_FOREGROUND': assetLauncherIconAdaptiveForegroundPath,
          'LAUNCHER_ICON_IMAGE_IOS': assetLauncherIosIconPath,
          'LAUNCHER_ICON_IMAGE_WEB': assetLauncherWebIconPath,
          'THEME_COLOR': launchIcons.entity.source?.backgroundColorHex?.toHex6WithHash() ?? '',
        },
      );
    } else {
      _logger.warn('backgroundColorHex is null in launch icons source');
    }

    if (splash.source?.backgroundColorHex != null) {
      _logger.info('- Prepare config for flutter_native_splash_template');
      await Process.start(
        'make',
        ['generate-native-splash-config'],
        workingDirectory: workingDirectoryPath,
        runInShell: true,
        environment: {
          'SPLASH_COLOR': splash.source?.backgroundColorHex?.toHex6WithHash() ?? '',
          'SPLASH_IMAGE': assetSplashIconPath,
          'ANDROID_12_SPLASH_COLOR': splash.source?.backgroundColorHex?.toHex6WithHash() ?? '',
        },
      );
    } else {
      _logger.warn('backgroundColorHex is null in splash source');
    }

    _logger.info('- Prepare config for package_rename_config_template');

    await Process.start(
      'make',
      ['generate-package-config'],
      workingDirectory: workingDirectoryPath,
      runInShell: true,
      environment: {
        'ANDROID_APP_NAME': application.name ?? '',
        'PACKAGE_NAME': application.androidPlatformId ?? '',
        'IOS_APP_NAME': application.name ?? '',
        'BUNDLE_ID': application.iosPlatformId ?? '',
      },
    );

    try {
      _configurePhoneEnv(application, theme, projectKeystoreDirectoryPath);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    return ExitCode.success.code;
  }

  // -------------------- THEME PIPE --------------------

  Future<void> _configureTheme(String applicationId, String themeId) async {
    await _writeColorSchemeConfig(applicationId, themeId);
    await _writePageLightConfig(applicationId, themeId);
    await _writeWidgetsLightConfig(applicationId, themeId);
    await _writeAppConfig(applicationId, themeId); // Змінений метод тут
  }

  Future<void> _writeColorSchemeConfig(String applicationId, String themeId) async {
    final colorSchemeDTO =
        await _datasource.getColorSchemeByVariant(applicationId: applicationId, themeId: themeId, variant: 'light');

    await _writeJsonToFile(_workingDirectory(assetLightColorSchemePath), colorSchemeDTO.config);
    // TODO: switch to real dark when available
    await _writeJsonToFile(_workingDirectory(assetDarkColorSchemePath), colorSchemeDTO.config);
  }

  Future<void> _writePageLightConfig(String applicationId, String themeId) async {
    final pageConfigDTO =
        await _datasource.getPageConfigByThemeVariant(applicationId: applicationId, themeId: themeId, variant: 'light');

    // MIGRATION: rewrite all URLs to asset://assets/images and download them
    final migrated = await _migrateUrisInJson(pageConfigDTO.config);

    // Optionally validate with model:
    // final model = ThemePageConfig.fromJson(migrated);
    // await _writeJsonToFile(_workingDirectory(assetPageLightConfig), model.toJson());

    await _writeJsonToFile(_workingDirectory(assetPageLightConfig), migrated);
    await _writeJsonToFile(_workingDirectory(assetPageDarkConfig), migrated);
  }

  Future<void> _writeWidgetsLightConfig(String applicationId, String themeId) async {
    final widgetsConfigDTO = await _datasource.getWidgetConfigByThemeVariant(
      applicationId: applicationId,
      themeId: themeId,
      variant: 'light',
    );

    // MIGRATION: rewrite all URLs to asset://assets/images and download them
    final migrated = await _migrateUrisInJson(widgetsConfigDTO.config);

    await _writeJsonToFile(_workingDirectory(assetWidgetsLightConfig), migrated);
    await _writeJsonToFile(_workingDirectory(assetWidgetsDarkConfig), migrated);
  }

  //
  // *** ПОЧАТОК РЕФАКТОРИНГУ ***
  //

  /// Змінений метод: тепер створює app.config.json та app.config.embeddeds.json
  Future<void> _writeAppConfig(String applicationId, String themeId) async {
    // 1. Отримуємо обидва джерела даних
    final featureAccessDto = await _datasource.getFeatureAccessByTheme(applicationId: applicationId, themeId: themeId);
    final embeds = await _datasource.getEmbeds(applicationId);

    // 2. Обробляємо та записуємо основний app.config.json
    // Запускаємо міграцію URIs лише для конфігурації функцій
    final migratedAppConfig = await _migrateUrisInJson(featureAccessDto.config);
    final appConfigPath = _workingDirectory(assetAppConfigPath);
    await _writeJsonToFile(appConfigPath, migratedAppConfig);

    // 3. Обробляємо та записуємо окремий app.config.embeddeds.json
    // Конвертуємо DTO в список JSON
    final embedsList = embeds.map((e) => e.toJson()).toList();

    // Ми НЕ запускаємо _migrateUrisInJson для embedsList,
    // оскільки оригінальний код був розроблений, щоб пропускати
    // міграцію для 'embeddedResources' (що є правильною поведінкою
    // для зовнішніх URI).

    final embedsConfigPath = _workingDirectory(assetAppConfigEmbeddedsPath); // Використовуємо нову константу
    await _writeJsonToFile(embedsConfigPath, embedsList);
  }

  // -------------------- TRANSLATIONS --------------------

  Future<void> _configureTranslations(String applicationId) async {
    final configFile = File(_workingDirectory('localizely.yml'));
    if (!configFile.existsSync()) {
      _logger.warn('localizely.yml file not found in the working directory.');
      return;
    }

    final configContent = await configFile.readAsString();
    final config = loadYaml(configContent);

    // ignore: dynamic_invocation, avoid_dynamic_calls
    final downloadFiles = config['download']['files'] as List;
    // ignore: dynamic_invocation, avoid_dynamic_calls
    final localeCodes = downloadFiles.map((file) => file['locale_code']).toList();

    _logger.info('Locales to be downloaded: ${localeCodes.join(', ')}');

    final translationsZip = await _httpClient.getTranslationFiles(applicationId);
    _logger.info('Locales downloaded: ${translationsZip.map((file) => file.name).join(', ')}');

    for (final file in translationsZip) {
      final filename = file.name;
      final localeCode = filename.split('.').first; // expected "<locale>.arb"

      if (localeCodes.contains(localeCode)) {
        final outPath = _workingDirectory('$translationsArbPath/app_$filename');
        await File(outPath).writeAsBytes(file.content);
        _logger.success('✓ Written successfully to $outPath');
      } else {
        _logger.info('Locale $localeCode is not in the list of desired locales, skipping.');
      }
    }
  }

  // -------------------- ENV & IO --------------------

  void _configurePhoneEnv(
    ApplicationDTO application,
    ThemeDTO theme,
    String projectKeystoreDirectoryPath,
  ) {
    final dartDefinePath = _workingDirectory(configureDartDefinePath);
    final applicationEnvironment = application.environment;

    // Make mutable copy
    final mutableEnvironment = Map<String, dynamic>.from(applicationEnvironment ?? {});
    mutableEnvironment['WEBTRIT_ANDROID_RELEASE_UPLOAD_KEYSTORE_PATH'] = projectKeystoreDirectoryPath;

    final env = mutableEnvironment.toStringifyJson();
    File(dartDefinePath).writeAsStringSync(env);
    _logger
      ..info('- Phone environment: $env')
      ..success('✓ Written successfully to $dartDefinePath');
  }

  /// Змінений метод: тепер приймає `dynamic` для запису List або Map
  Future<void> _writeJsonToFile(String pathStr, dynamic jsonContent) async {
    // Використовуємо стандартний кодер, який працює і для Map, і для List.
    // .withIndent('  ') робить "pretty-print" JSON,
    // що, ймовірно, і робив ваш метод toStringifyJson().
    final jsonString = JsonEncoder.withIndent('  ').convert(jsonContent);

    // Тепер ми передаємо коректний String у writeAsStringSync
    File(pathStr).writeAsStringSync(jsonString);
    _logger.success('✓ Written successfully to $pathStr');
  }

  //
  // *** КІНЕЦЬ РЕФАКТОРИНГУ ***
  //

  String _workingDirectory(String relativePath) {
    return path.normalize(path.join(workingDirectoryPath, relativePath));
  }

  Future<void> _downloadAndSave({
    required String? url,
    required String relativePath,
    String? assetLabel,
  }) async {
    if (url == null || url.isEmpty) {
      _logger.warn('Skip ${assetLabel ?? 'asset'}: empty URL');
      return;
    }
    try {
      final bytes = await _httpClient.getBytes(url);
      final outPath = _workingDirectory(relativePath);
      if (bytes != null) {
        File(outPath).createSync(recursive: true);
        File(outPath).writeAsBytesSync(bytes);
        _logger.success('✓ Written successfully to $outPath');
      } else {
        _logger.err('✗ Failed to download ${assetLabel ?? 'asset'} from $url');
      }
    } catch (e) {
      _logger.err('✗ Error while downloading ${assetLabel ?? 'asset'}: $e');
    }
  }

  // -------------------- URL → ASSET MIGRATION --------------------

  Future<Map<String, dynamic>> _migrateUrisInJson(Map<String, dynamic> json) async {
    final rewriter = _JsonUriRewriter(
      fetchBytes: _httpClient.getBytes,
      assetsRootOnDisk: _workingDirectory(_imagesAssetDiskDir),
      assetLogicalPrefix: _imagesAssetLogicalPrefix,
      deriveFilename: _deriveFilenameFromUrl,
      sniffExt: _sniffImageExt,
      cache: _assetCache,
      info: _logger.info,
      warn: _logger.warn,
      err: _logger.err,
    );

    final transformed = await rewriter.transform(json);
    return Map<String, dynamic>.from(transformed as Map);
  }

  // Stable filename = sanitized basename + short sha1(url|query) + extension
  String _deriveFilenameFromUrl(String url, {String? fallbackExt}) {
    final uri = Uri.tryParse(url);
    final last = (uri?.pathSegments.isNotEmpty ?? false) ? uri!.pathSegments.last : '';
    final base = last.isEmpty ? 'image' : last;

    String sanitize(String name) =>
        name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_\-]'), '_').replaceAll(RegExp('_+'), '_');

    String? guessExt(String basename) {
      final ext = path.extension(basename).toLowerCase().replaceFirst('.', '');
      const known = {'png', 'jpg', 'jpeg', 'webp', 'gif', 'svg', 'bmp', 'ico', 'avif'};
      return ext.isEmpty ? null : (known.contains(ext) ? ext : null);
    }

    final q = uri?.query ?? '';
    final hash = sha1.convert(utf8.encode('$url|$q')).toString().substring(0, 10);

    final ext = guessExt(base) ?? fallbackExt ?? 'bin';
    final stem = sanitize(base.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), ''));
    return '${stem.isEmpty ? 'image' : stem}_$hash.$ext';
  }

  String? _sniffImageExt(List<int> bytes) {
    if (bytes.length >= 8) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'png';
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
      if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes.length >= 12 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'webp';
      }
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'gif';
      if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'bmp';
      if (bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x01 && bytes[3] == 0x00) return 'ico';
    }
    try {
      final head = utf8.decode(bytes.take(200).toList(), allowMalformed: true).toLowerCase();
      if (head.contains('<svg')) return 'svg';
    } catch (_) {}
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70 &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'avif') return 'avif';
    return null;
  }
}

/// Internal, schema-agnostic JSON rewriter.
/// Rewrites any URL-looking value under keys: `uri`, `url`, `*Url`, `*URL`,
/// and also `imageSource: { uri: ... }`.
class _JsonUriRewriter {
  _JsonUriRewriter({
    required this.fetchBytes,
    required this.assetsRootOnDisk,
    required this.assetLogicalPrefix,
    required this.deriveFilename,
    required this.sniffExt,
    required this.cache,
    required this.info,
    required this.warn,
    required this.err,
  });

  final Future<List<int>?> Function(String url) fetchBytes;
  final String assetsRootOnDisk;
  final String assetLogicalPrefix;
  final String Function(String url, {String? fallbackExt}) deriveFilename;
  final String? Function(List<int> bytes) sniffExt;
  final Map<String, String> cache;
  final void Function(String) info;
  final void Function(String) warn;
  final void Function(String) err;

  bool _looksUrl(Object? v) => v is String && (v.startsWith('http://') || v.startsWith('https://'));

  bool _insideEmbeddedResources(List<String> path) {
    // Якщо у шляху вже зустрічався ключ 'embeddedResources' — пропускаємо всю цю гілку без змін
    return path.contains('embeddedResources');
  }

  Future<dynamic> transform(dynamic node, {List<String> path = const []}) async {
    // Якщо ми всередині embeddedResources — нічого не міняємо взагалі
    if (_insideEmbeddedResources(path)) {
      return node;
    }

    if (node is Map) {
      final result = <String, dynamic>{};
      for (final entry in node.entries) {
        final k = entry.key.toString();
        final v = entry.value;

        // Типові ключі з урлами
        final urlish = k == 'uri' || k == 'url' || k.endsWith('Url') || k.endsWith('URL');

        if (urlish && _looksUrl(v)) {
          result[k] = await _downloadAndMakeAssetUri(v as String);
          continue;
        }

        // Поширений випадок: { imageSource: { uri: ... } }
        if (k == 'imageSource' && v is Map && _looksUrl(v['uri'])) {
          final newUri = await _downloadAndMakeAssetUri(v['uri'] as String);
          final newImageSource = Map<String, dynamic>.from(v)..['uri'] = newUri;
          result[k] = newImageSource;
          continue;
        }

        // Рекурсія з оновленим шляхом
        result[k] = await transform(v, path: [...path, k]);
      }
      return result;
    } else if (node is List) {
      final out = <dynamic>[];
      for (var i = 0; i < node.length; i++) {
        out.add(await transform(node[i], path: [...path, '[$i]']));
      }
      return out;
    } else {
      return node;
    }
  }

  Future<String> _downloadAndMakeAssetUri(String url) async {
    if (cache.containsKey(url)) return cache[url]!;

    final bytes = await fetchBytes(url);
    if (bytes == null) {
      err('Failed to download: $url');
      return url;
    }

    final ext = sniffExt(bytes) ?? 'bin';
    final filename = deriveFilename(url, fallbackExt: ext);

    final outDisk = path.normalize(path.join(assetsRootOnDisk, filename));
    await File(outDisk).create(recursive: true);
    await File(outDisk).writeAsBytes(bytes);

    final logical = '$assetLogicalPrefix/$filename';
    info('Saved $url → $logical');
    cache[url] = logical;
    return logical;
  }
}

extension HexSanitizer on String {
  String toHex6() {
    final hex = replaceAll('#', '').toUpperCase();
    if (hex.length == 8) return hex.substring(2);
    if (hex.length == 6) return hex;
    throw FormatException('Invalid hex color string: $this');
  }

  String toHex6WithHash() => '#${toHex6()}';
}
