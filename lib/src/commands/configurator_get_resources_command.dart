import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:data/datasource/datasource.dart';
import 'package:data/dto/dto.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:webtrit_appearance_theme/models/models.dart';
import 'package:yaml/yaml.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

const _applicationId = 'applicationId';
const _token = 'token';
const _keystoresPath = 'keystores-path';
const _cacheSessionDataPath = 'cache-session-data-path';

const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

/// Fetches resources from Configurator and prepares local assets/configs.
///
/// Responsibilities:
/// - Validates input/options and working directory
/// - Fetches application, theme, and assets via backend datasource
/// - Writes theme configs, images, translations, and build cache
/// - Prepares Make-based configs for icons/splash/package rename
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
        help: 'Path to file which cache temporarily stores user session data to enhance performance '
            'and maintain state across different processes.',
      );
  }

  @override
  String get name => 'configurator-resources';

  final HttpClient _httpClient;
  final ConfiguratorBackandDatasource _datasource;

  @override

  /// Short command description and optional directory argument.
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Get resources to customize application',
      )
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
    // Prepare files for generating Google services or another file in the next command, such as `configurator_generate_command`.
    // This ensures a continuous flow of execution for multiple commands.
    final buildConfig = {
      // Android build configuration
      bundleIdAndroidField: application.androidPlatformId,
      buildNameAndroidField: application.androidVersion?.buildName,
      buildNumberAndroidField: application.androidVersion?.buildNumber,
      // IOS build configuration
      bundleIdIosField: application.iosPlatformId,
      buildNameIOSField: application.iosVersion?.buildName,
      buildNumberIOSField: application.iosVersion?.buildNumber,
      // Path to keystore
      keystorePathField: projectKeystoreDirectoryPath,
    };

    final buildConfigPath = _workingDirectory(cacheSessionDataPath);
    File(buildConfigPath).writeAsStringSync(buildConfig.toStringifyJson());
    _logger.success('✓ Written successfully to $buildConfigPath');

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

    // TODO(Serdun): Re check structure of naming
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
    //
    // final notificationLogo = await _httpClient.getBytes(theme.launchAssets.notificationLogoUrl);
    // final notificationLogoPath = _workingDirectory(assetIconIosNotificationTemplateImagePath);
    // if (notificationLogo != null) {
    //   File(notificationLogoPath).writeAsBytesSync(notificationLogo);
    //   _logger.success('✓ Written successfully to $notificationLogoPath');
    // } else {
    //   _logger.err('✗ Failed to write $notificationLogoPath with $notificationLogo');
    // }

    // Widget config and onboarding logos are handled in _writeWidgetsLightConfig to avoid duplicate requests.

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

  /// Updates image URIs in the page light config to reference local asset files.
  /// The original config stores remote URLs for easier management and downloading.
  /// During the build process, all images are downloaded to local assets and the config is rewritten to use local asset URIs.
  /// This approach is not flexible for future changes and should be refactored later.
  ThemeWidgetConfig _patchOnboardingLogoUris(ThemeWidgetConfig cfg) {
    final primary = cfg.imageAssets.primaryOnboardingLogo;
    final secondary = cfg.imageAssets.secondaryOnboardingLogo;

    return cfg.copyWith(
      imageAssets: cfg.imageAssets.copyWith(
        primaryOnboardingLogo: primary.copyWith(
          imageSource: (primary.imageSource?.copyWith(
                uri: 'asset://assets/primary_onboardin_logo.svg',
              )) ??
              const ImageSource(uri: 'asset://assets/primary_onboardin_logo.svg'),
        ),
        secondaryOnboardingLogo: secondary.copyWith(
          imageSource: (secondary.imageSource?.copyWith(
                uri: 'asset://assets/secondary_onboardin_logo.svg',
              )) ??
              const ImageSource(uri: 'asset://assets/secondary_onboardin_logo.svg'),
        ),
      ),
    );
  }

  /// Updates image URIs in the page light config to reference local asset files.
  /// The original config stores remote URLs for easier management and downloading.
  /// During the build process, all images are downloaded to local assets and the config is rewritten to use local asset URIs.
  /// This approach is not flexible for future changes and should be refactored later.
  ThemePageConfig _patchPageLightConfigUris(ThemePageConfig cfg) {
    final loginImage = cfg.login.imageSource;

    return cfg.copyWith(
        login: cfg.login.copyWith(
      imageSource: (loginImage?.copyWith(
            uri: 'asset://assets/primary_onboardin_logo.svg',
          )) ??
          const ImageSource(uri: 'asset://assets/primary_onboardin_logo.svg'),
    ));
  }

  /// Writes phone environment define file with required variables.
  void _configurePhoneEnv(
    ApplicationDTO application,
    ThemeDTO theme,
    String projectKeystoreDirectoryPath,
  ) {
    final dartDefinePath = _workingDirectory(configureDartDefinePath);
    final applicationEnvironment = application.environment;

    // Create a mutable copy if the environment is unmodifiable
    final mutableEnvironment = Map<String, dynamic>.from(applicationEnvironment ?? {});

    mutableEnvironment['WEBTRIT_ANDROID_RELEASE_UPLOAD_KEYSTORE_PATH'] = projectKeystoreDirectoryPath;

    // Convert the updated environment to a JSON string
    final env = mutableEnvironment.toStringifyJson();
    File(dartDefinePath).writeAsStringSync(env);
    _logger
      ..info('- Phone environment: $env')
      ..success('✓ Written successfully to $dartDefinePath');
  }

  /// Fetches theme configs and writes them to asset files.
  Future<void> _configureTheme(String applicationId, String themeId) async {
    await _writeColorSchemeConfig(applicationId, themeId);
    await _writePageLightConfig(applicationId, themeId);
    await _writeWidgetsLightConfig(applicationId, themeId);
    await _writeAppConfig(applicationId, themeId);
  }

  /// Writes color scheme (light and temporary dark copy).
  Future<void> _writeColorSchemeConfig(String applicationId, String themeId) async {
    final colorSchemeDTO =
        await _datasource.getColorSchemeByVariant(applicationId: applicationId, themeId: themeId, variant: 'light');

    await _writeJsonToFile(_workingDirectory(assetLightColorSchemePath), colorSchemeDTO.config);
    // TODO(Serdun): Change scheme to dark when it will be implemented
    await _writeJsonToFile(_workingDirectory(assetDarkColorSchemePath), colorSchemeDTO.config);
  }

  /// Writes page config for light (and temporary dark copy).
  Future<void> _writePageLightConfig(String applicationId, String themeId) async {
    final pageConfigDTO =
        await _datasource.getPageConfigByThemeVariant(applicationId: applicationId, themeId: themeId, variant: 'light');
    final themePageConfig = ThemePageConfig.fromJson(pageConfigDTO.config);
    final assetConfig = _patchPageLightConfigUris(themePageConfig);
    await _writeJsonToFile(_workingDirectory(assetPageLightConfig), assetConfig.toJson());
    // TODO(Serdun): Change scheme to dark when it will be implemented
    await _writeJsonToFile(_workingDirectory(assetPageDarkConfig), assetConfig.toJson());
  }

  /// Writes widgets config for light (and temporary dark copy).
  Future<void> _writeWidgetsLightConfig(String applicationId, String themeId) async {
    final widgetsConfigDTO = await _datasource.getWidgetConfigByThemeVariant(
      applicationId: applicationId,
      themeId: themeId,
      variant: 'light',
    );
    final themeWidgetConfig = ThemeWidgetConfig.fromJson(widgetsConfigDTO.config);

    // Download onboarding logos once here to avoid duplicate API calls.
    final primaryLogoUrl = themeWidgetConfig.imageAssets.primaryOnboardingLogo.imageSource?.uri;
    await _downloadAndSave(
      url: primaryLogoUrl,
      relativePath: assetImagePrimaryOnboardingLogoPath,
      assetLabel: 'primary onboarding logo',
    );

    final secondaryLogoUrl = themeWidgetConfig.imageAssets.secondaryOnboardingLogo.imageSource?.uri;
    await _downloadAndSave(
      url: secondaryLogoUrl,
      relativePath: assetImageSecondaryOnboardingLogoPath,
      assetLabel: 'secondary onboarding logo',
    );

    final assetConfig = _patchOnboardingLogoUris(themeWidgetConfig);
    await _writeJsonToFile(_workingDirectory(assetWidgetsLightConfig), assetConfig.toJson());
    // TODO(Serdun): Change scheme to dark when it will be implemented
    await _writeJsonToFile(_workingDirectory(assetWidgetsDarkConfig), assetConfig.toJson());
  }

  /// Writes a JSON map to a file with success logging.
  Future<void> _writeJsonToFile(String path, Map<String, dynamic> jsonContent) async {
    File(path).writeAsStringSync(jsonContent.toStringifyJson());
    _logger.success('✓ Written successfully to $path');
  }

  /// Writes application feature access config.
  Future<void> _writeAppConfig(String applicationId, String themeId) async {
    final appConfigDTO = await _datasource.getFeatureAccessByTheme(applicationId: applicationId, themeId: themeId);

    final appConfigPath = _workingDirectory(assetAppConfigPath);

    await _writeJsonToFile(appConfigPath, appConfigDTO.config);
  }

  /// Downloads translations and writes only locales declared in `localizely.yml`.
  Future<void> _configureTranslations(String applicationId) async {
    final configFile = File(_workingDirectory('localizely.yml'));
    if (!configFile.existsSync()) {
      _logger.warn('localizely.yml file not found in the working directory.');
      return;
    }

    final configContent = await configFile.readAsString();
    final config = loadYaml(configContent);

    // Extract the download locale codes
    // ignore: dynamic_invocation, avoid_dynamic_calls
    final downloadFiles = config['download']['files'] as List;
    // ignore: dynamic_invocation, avoid_dynamic_calls
    final localeCodes = downloadFiles.map((file) => file['locale_code']).toList();

    // Display the locale codes before starting downloading
    _logger.info('Locales to be downloaded: ${localeCodes.join(', ')}');

    // Fetch the translation files
    final translationsZip = await _httpClient.getTranslationFiles(applicationId);
    _logger.info('Locales downloaded: ${translationsZip.map((file) => file.name).join(', ')}');

    // Write the translation files to the working directory
    for (final file in translationsZip) {
      final filename = file.name;
      final localeCode = filename.split('.').first; // assuming the file name is in the format localeCode.arb

      // TODO(Serdun): Add filtration of translations to API
      // Check if the locale code is in the list of desired locale codes
      if (localeCodes.contains(localeCode)) {
        final data = file.content;
        final outPath = _workingDirectory('$translationsArbPath/app_$filename');
        await File(outPath).writeAsBytes(data);

        _logger.success('✓ Written successfully to $outPath');
      } else {
        _logger.info('Locale $localeCode is not in the list of desired locales, skipping.');
      }
    }
  }

  /// Resolves an absolute path within the working directory.
  String _workingDirectory(String relativePath) {
    return path.normalize(path.join(workingDirectoryPath, relativePath));
  }

  /// Downloads bytes from [url] and writes them to [relativePath].
  /// Logs success or a descriptive error without throwing.
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
        File(outPath).writeAsBytesSync(bytes);
        _logger.success('✓ Written successfully to $outPath');
      } else {
        _logger.err('✗ Failed to download ${assetLabel ?? 'asset'} from $url');
      }
    } catch (e) {
      _logger.err('✗ Error while downloading ${assetLabel ?? 'asset'}: $e');
    }
  }
}

/// Hex color helpers used to normalize values for configs.
extension HexSanitizer on String {
  String toHex6() {
    final hex = replaceAll('#', '').toUpperCase();

    if (hex.length == 8) {
      return hex.substring(2);
    } else if (hex.length == 6) {
      return hex;
    } else {
      throw FormatException('Invalid hex color string: $this');
    }
  }

  String toHex6WithHash() => '#${toHex6()}';
}
