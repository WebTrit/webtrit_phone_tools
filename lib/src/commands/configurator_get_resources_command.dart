import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:data/datasource/datasource.dart';
import 'package:data/dto/dto.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

const _applicationId = 'applicationId';
const _token = 'token';
const _keystoresPath = 'keystores-path';
const _cacheSessionDataPath = 'cache-session-data-path';

const _publisherAppDemoFlagName = 'demo';
const _publisherAppClassicFlagName = 'classic';

const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

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
      )
      ..addFlag(
        _publisherAppDemoFlagName,
        help: 'Force-enable the demo app flow, disregarding the configuration value.',
        negatable: false,
      )
      ..addFlag(
        _publisherAppClassicFlagName,
        help: 'Force-enable the classic app flow, disregarding the configuration value.',
        negatable: false,
      );
  }

  @override
  String get name => 'configurator-resources';

  final HttpClient _httpClient;
  final ConfiguratorBackandDatasource _datasource;

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Get resources for customize application',
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

    final adaptiveIconBackground = await _httpClient.getBytes(theme.splashAssets.pictureUrl);
    final adaptiveIconBackgroundPath = _workingDirectory(assetSplashIconPath);
    if (adaptiveIconBackground != null) {
      File(adaptiveIconBackgroundPath).writeAsBytesSync(adaptiveIconBackground);
      _logger.success('✓ Written successfully to $adaptiveIconBackgroundPath');
    } else {
      _logger.err('✗ Failed to write $adaptiveIconBackgroundPath with $adaptiveIconBackground');
    }

    final androidLauncherIcon = await _httpClient.getBytes(theme.launchAssets.androidLauncherIconUrl);
    final androidLauncherIconPath = _workingDirectory(assetLauncherAndroidIconPath);
    if (androidLauncherIcon != null) {
      File(androidLauncherIconPath).writeAsBytesSync(androidLauncherIcon);
      _logger.success('✓ Written successfully to $androidLauncherIconPath');
    } else {
      _logger.err('✗ Failed to write $androidLauncherIconPath with $androidLauncherIcon');
    }

    // TODO(Serdun): Re check structure of naming
    final adaptiveIconForeground = await _httpClient.getBytes(theme.launchAssets.adaptiveIconBackgroundUrl);
    final adaptiveIconForegroundPath = _workingDirectory(assetLauncherIconAdaptiveForegroundPath);
    if (adaptiveIconForeground != null) {
      File(adaptiveIconForegroundPath).writeAsBytesSync(adaptiveIconForeground);
      _logger.success('✓ Written successfully to $adaptiveIconForegroundPath');
    } else {
      _logger.err('✗ Failed to write $adaptiveIconForegroundPath with $adaptiveIconForeground');
    }

    final webLauncherIcon = await _httpClient.getBytes(theme.launchAssets.webLauncherIconUrl);
    final webLauncherIconPath = _workingDirectory(assetLauncherWebIconPath);
    if (webLauncherIcon != null) {
      File(webLauncherIconPath).writeAsBytesSync(webLauncherIcon);
      _logger.success('✓ Written successfully to $webLauncherIconPath');
    } else {
      _logger.err('✗ Failed to write $webLauncherIconPath with $webLauncherIcon');
    }

    final iosLauncherIcon = await _httpClient.getBytes(theme.launchAssets.iosLauncherIconUrl);
    final iosLauncherIconPath = _workingDirectory(assetLauncherIosIconPath);
    if (iosLauncherIcon != null) {
      File(iosLauncherIconPath).writeAsBytesSync(iosLauncherIcon);
      _logger.success('✓ Written successfully to $iosLauncherIconPath');
    } else {
      _logger.err('✗ Failed to write $iosLauncherIconPath with $iosLauncherIcon');
    }

    final notificationLogo = await _httpClient.getBytes(theme.launchAssets.notificationLogoUrl);
    final notificationLogoPath = _workingDirectory(assetIconIosNotificationTemplateImagePath);
    if (notificationLogo != null) {
      File(notificationLogoPath).writeAsBytesSync(notificationLogo);
      _logger.success('✓ Written successfully to $notificationLogoPath');
    } else {
      _logger.err('✗ Failed to write $notificationLogoPath with $notificationLogo');
    }

    final metadataPrimaryOnboardingLogoUrl = theme.themeWidgetConfig.imageAssets.primaryOnboardingLogo.metadata
        .getString(ImageAssetsConfig.metadataPrimaryOnboardingLogoUrl);
    final primaryOnboardingLogo = await _httpClient.getBytes(metadataPrimaryOnboardingLogoUrl);
    final primaryOnboardingLogoPath = _workingDirectory(assetImagePrimaryOnboardingLogoPath);
    if (primaryOnboardingLogo != null) {
      File(primaryOnboardingLogoPath).writeAsBytesSync(primaryOnboardingLogo);
      _logger.success('✓ Written successfully to $primaryOnboardingLogoPath');
    } else {
      _logger.err('✗ Failed to write $primaryOnboardingLogoPath with $primaryOnboardingLogo');
    }

    final metadataSecondaryOnboardingLogoUrl = theme.themeWidgetConfig.imageAssets.secondaryOnboardingLogo.metadata
        .getString(ImageAssetsConfig.metadataSecondaryOnboardingLogoUrl);
    final secondaryOnboardingLogo = await _httpClient.getBytes(metadataSecondaryOnboardingLogoUrl);
    final secondaryOnboardingLogoPath = _workingDirectory(assetImageSecondaryOnboardingLogoPath);
    if (secondaryOnboardingLogo != null) {
      File(secondaryOnboardingLogoPath).writeAsBytesSync(secondaryOnboardingLogo);
      _logger.success('✓ Written successfully to $secondaryOnboardingLogoPath');
    } else {
      _logger.err('✗ Failed to write $secondaryOnboardingLogoPath with $secondaryOnboardingLogo');
    }

    try {
      await _configureTheme(theme);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    _logger.info('- Prepare config for flutter_launcher_icons_template');

    if (theme.launchAssets.backgroundColor != null) {
      await Process.start(
        'make',
        ['generate-launcher-icons-config'],
        workingDirectory: workingDirectoryPath,
        runInShell: true,
        environment: {
          'LAUNCHER_ICON_IMAGE_ANDROID': assetLauncherAndroidIconPath,
          'ICON_BACKGROUND_COLOR': theme.launchAssets.backgroundColor ?? '',
          'LAUNCHER_ICON_FOREGROUND': assetLauncherIconAdaptiveForegroundPath,
          'LAUNCHER_ICON_IMAGE_IOS': assetLauncherIosIconPath,
          'LAUNCHER_ICON_IMAGE_WEB': assetLauncherWebIconPath,
          'THEME_COLOR': theme.launchAssets.backgroundColor ?? '',
        },
      );
    } else {
      _logger.warn('adaptiveIconBackground: ${theme.launchAssets.backgroundColor} adaptiveIconBackground');
    }

    if (theme.splashAssets.color != null) {
      _logger.info('- Prepare config for flutter_native_splash_template');
      await Process.start(
        'make',
        ['generate-native-splash-config'],
        workingDirectory: workingDirectoryPath,
        runInShell: true,
        environment: {
          'SPLASH_COLOR': theme.splashAssets.color ?? '',
          'SPLASH_IMAGE': assetSplashIconPath,
          'ANDROID_12_SPLASH_COLOR': theme.splashAssets.color ?? '',
        },
      );
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

  // Configures the phone environment for the application by setting environment variables
  // and writing them to a Dart define file.
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

  Future<void> _configureTheme(ThemeDTO theme) async {
    await _writeColorSchemeConfig(theme);
    await _writePageLightConfig(theme);
    await _writeWidgetsLightConfig(theme);
    await _writeAppConfig(theme);
  }

  Future<void> _writeColorSchemeConfig(ThemeDTO theme) async {
    await _writeJsonToFile(_workingDirectory(assetLightColorSchemePath), theme.colorSchemeConfig.toJson());
    // TODO(Serdun): Change scheme to dark when it will be implemented
    await _writeJsonToFile(_workingDirectory(assetDarkColorSchemePath), theme.colorSchemeConfig.toJson());
  }

  Future<void> _writePageLightConfig(ThemeDTO theme) async {
    await _writeJsonToFile(_workingDirectory(assetPageLightConfig), theme.themePageConfig.toJson());
    // TODO(Serdun): Change scheme to dark when it will be implemented
    await _writeJsonToFile(_workingDirectory(assetPageDarkConfig), theme.themePageConfig.toJson());
  }

  Future<void> _writeWidgetsLightConfig(ThemeDTO theme) async {
    await _writeJsonToFile(_workingDirectory(assetWidgetsLightConfig), theme.themeWidgetConfig.toJson());
    // TODO(Serdun): Change scheme to dark when it will be implemented
    await _writeJsonToFile(_workingDirectory(assetWidgetsDarkConfig), theme.themeWidgetConfig.toJson());
  }

  Future<void> _writeJsonToFile(String path, Map<String, dynamic> jsonContent) async {
    File(path).writeAsStringSync(jsonContent.toStringifyJson());
    _logger.success('✓ Written successfully to $path');
  }

  Future<void> _writeAppConfig(ThemeDTO theme) async {
    final appConfigPath = _workingDirectory(assetAppConfigPath);
    final appConfig = theme.appConfig;

    final assetUrlMappings = <int, Uri>{};
    for (final value in appConfig.embeddedResources) {
      if (value.uriOrNull?.queryParameters['type'] == 'download' && value.uriOrNull != null) {
        await _handleDownloadAsset(value, assetUrlMappings);
      }
    }

    final updatedEmbeddedResources = _updateEmbeddedResources(appConfig.embeddedResources, assetUrlMappings);
    await _writeJsonToFile(appConfigPath, appConfig.copyWith(embeddedResources: updatedEmbeddedResources).toJson());
  }

  Future<void> _handleDownloadAsset(EmbeddedResource value, Map<int, Uri> assetUrlMappings) async {
    final url = value.uriOrNull.toString();
    final fileName = '${value.id}.html';
    final downloadPath = _workingDirectory('assets/themes/$fileName');

    final file = await _httpClient.getBytes(url);
    if (file != null) {
      await File(downloadPath).writeAsBytes(file);
      _logger.success('✓ Written successfully to $downloadPath');

      final changeUrlToUri = 'asset://assets/themes/$fileName';
      assetUrlMappings[value.id] = Uri.parse(changeUrlToUri);
    }
  }

  List<EmbeddedResource> _updateEmbeddedResources(
      List<EmbeddedResource> resources, Map<int, Uri> changeUrlAssetsToURIEmbedddeds) {
    return resources.map((e) {
      final uri = changeUrlAssetsToURIEmbedddeds[e.id] ?? e.uriOrNull;
      return e.copyWith(uri: uri.toString());
    }).toList();
  }

  Future<void> _configureTranslations(String applicationId) async {
    // Read and parse the localizely.yml file
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
        final data = file.content as Uint8List;
        final outPath = _workingDirectory('$translationsArbPath/app_$filename');
        await File(outPath).writeAsBytes(data);

        _logger.success('✓ Written successfully to $outPath');
      } else {
        _logger.info('Locale $localeCode is not in the list of desired locales, skipping.');
      }
    }
  }

  String _workingDirectory(String relativePath) {
    return path.normalize(path.join(workingDirectoryPath, relativePath));
  }
}
