import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:dto/dto.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mustache_template/mustache.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/gen/assets.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

const _applicationId = 'applicationId';
const _keystoresPath = 'keystores-path';
const _cacheSessionDataPath = 'cache-session-data-path';

const _publisherAppDemoFlag = 'demo';
const _publisherAppClassicFlag = 'classic';

const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

class ConfiguratorGetResourcesCommand extends Command<int> {
  ConfiguratorGetResourcesCommand({
    required Logger logger,
    required HttpClient httpClient,
  })  : _logger = logger,
        _httpClient = httpClient {
    argParser
      ..addOption(
        _applicationId,
        help: 'Configurator application id.',
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
        _publisherAppDemoFlag,
        help: 'Force-enable the demo app flow, disregarding the configuration value.',
        negatable: false,
      )
      ..addFlag(
        _publisherAppClassicFlag,
        help: 'Force-enable the classic app flow, disregarding the configuration value.',
        negatable: false,
      );
  }

  @override
  String get name => 'configurator-resources';

  final HttpClient _httpClient;

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

    final publisherAppDemoFlag = commandArgResults[_publisherAppDemoFlag] as bool;
    final publisherAppClassicFlag = commandArgResults[_publisherAppClassicFlag] as bool;

    late ApplicationDTO application;
    late ThemeDTO theme;

    try {
      application = await _httpClient.getApplication(applicationId);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    if (application.theme == null) {
      _logger.err('Application $applicationId does not have a default theme');
      return ExitCode.usage.code;
    }

    try {
      theme = await _httpClient.getTheme(applicationId, application.theme!);
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
    File(buildConfigPath).writeAsStringSync(buildConfig.toJson());
    _logger.success('✓ Written successfully to $buildConfigPath');

    final adaptiveIconBackground = await _httpClient.getBytes(theme.images?.adaptiveIconBackground);
    final adaptiveIconBackgroundPath = _workingDirectory(assetSplashIconPath);
    if (adaptiveIconBackground != null) {
      File(adaptiveIconBackgroundPath).writeAsBytesSync(adaptiveIconBackground);
      _logger.success('✓ Written successfully to $adaptiveIconBackgroundPath');
    } else {
      _logger.err('✗ Failed to write $adaptiveIconBackgroundPath with $adaptiveIconBackground');
    }

    final adaptiveIconForeground = await _httpClient.getBytes(theme.images?.adaptiveIconForeground);
    final adaptiveIconForegroundPath = _workingDirectory(assetLauncherIconAdaptiveForegroundPath);
    if (adaptiveIconForeground != null) {
      File(adaptiveIconForegroundPath).writeAsBytesSync(adaptiveIconForeground);
      _logger.success('✓ Written successfully to $adaptiveIconForegroundPath');
    } else {
      _logger.err('✗ Failed to write $adaptiveIconForegroundPath with $adaptiveIconForeground');
    }

    final webLauncherIcon = await _httpClient.getBytes(theme.images?.webLauncherIcon);
    final webLauncherIconPath = _workingDirectory(assetLauncherWebIconPath);
    if (webLauncherIcon != null) {
      File(webLauncherIconPath).writeAsBytesSync(webLauncherIcon);
      _logger.success('✓ Written successfully to $webLauncherIconPath');
    } else {
      _logger.err('✗ Failed to write $webLauncherIconPath with $webLauncherIcon');
    }

    final androidLauncherIcon = await _httpClient.getBytes(theme.images?.androidLauncherIcon);
    final androidLauncherIconPath = _workingDirectory(assetLauncherAndroidIconPath);
    if (androidLauncherIcon != null) {
      File(androidLauncherIconPath).writeAsBytesSync(androidLauncherIcon);
      _logger.success('✓ Written successfully to $androidLauncherIconPath');
    } else {
      _logger.err('✗ Failed to write $androidLauncherIconPath with $androidLauncherIcon');
    }

    final iosLauncherIcon = await _httpClient.getBytes(theme.images?.iosLauncherIcon);
    final iosLauncherIconPath = _workingDirectory(assetLauncherIosIconPath);
    if (iosLauncherIcon != null) {
      File(iosLauncherIconPath).writeAsBytesSync(iosLauncherIcon);
      _logger.success('✓ Written successfully to $iosLauncherIconPath');
    } else {
      _logger.err('✗ Failed to write $iosLauncherIconPath with $iosLauncherIcon');
    }

    final notificationLogo = await _httpClient.getBytes(theme.images?.notificationLogo);
    final notificationLogoPath = _workingDirectory(assetIconIosNotificationTemplateImagePath);
    if (notificationLogo != null) {
      File(notificationLogoPath).writeAsBytesSync(notificationLogo);
      _logger.success('✓ Written successfully to $notificationLogoPath');
    } else {
      _logger.err('✗ Failed to write $notificationLogoPath with $notificationLogo');
    }

    final primaryOnboardingLogo = await _httpClient.getBytes(theme.images?.primaryOnboardingLogo);
    final primaryOnboardingLogoPath = _workingDirectory(assetImagePrimaryOnboardingLogoPath);
    if (primaryOnboardingLogo != null) {
      File(primaryOnboardingLogoPath).writeAsBytesSync(primaryOnboardingLogo);
      _logger.success('✓ Written successfully to $primaryOnboardingLogoPath');
    } else {
      _logger.err('✗ Failed to write $primaryOnboardingLogoPath with $primaryOnboardingLogo');
    }

    final secondaryOnboardingLogo = await _httpClient.getBytes(theme.images?.secondaryOnboardingLogo);
    final secondaryOnboardingLogoPath = _workingDirectory(assetImageSecondaryOnboardingLogoPath);
    if (secondaryOnboardingLogo != null) {
      File(secondaryOnboardingLogoPath).writeAsBytesSync(secondaryOnboardingLogo);
      _logger.success('✓ Written successfully to $secondaryOnboardingLogoPath');
    } else {
      _logger.err('✗ Failed to write $secondaryOnboardingLogoPath with $secondaryOnboardingLogo');
    }

    final themePath = _workingDirectory(assetThemePath);
    File(themePath).writeAsStringSync(theme.toThemeSettingJsonString());
    _logger.success('✓ Written successfully to $themePath');

    if (theme.colors?.launch?.adaptiveIconBackground != null && theme.colors?.launch?.adaptiveIconBackground != null) {
      _logger.info('- Prepare config for flutter_launcher_icons_template');
      final flutterLauncherIconsMapValues = {
        'adaptive_icon_background': theme.colors?.launch?.adaptiveIconBackground,
        'theme_color': theme.colors?.launch?.adaptiveIconBackground,
      };
      final flutterLauncherIconsTemplate =
          Template(StringifyAssets.flutterLauncherIconsTemplate, htmlEscapeValues: false);
      final flutterLauncherIcons = flutterLauncherIconsTemplate.renderString(flutterLauncherIconsMapValues);
      final flutterLauncherIconsPath = _workingDirectory(configPathLaunchPath);
      File(flutterLauncherIconsPath).writeAsStringSync(flutterLauncherIcons);
      _logger.success('✓ Written successfully to $flutterLauncherIconsPath');
    }

    if (theme.colors?.launch?.splashBackground != null) {
      _logger.info('- Prepare config for flutter_native_splash_template');

      final flutterNativeSplashMapValues = {
        'background': theme.colors?.launch?.splashBackground?.replaceFirst('ff', ''),
      };
      final flutterNativeSplashTemplate =
          Template(StringifyAssets.flutterNativeSplashTemplate, htmlEscapeValues: false);
      final flutterNativeSplash = flutterNativeSplashTemplate.renderString(flutterNativeSplashMapValues);
      final flutterNativeSplashPath = _workingDirectory(configPathSplashPath);
      File(flutterNativeSplashPath).writeAsStringSync(flutterNativeSplash);
      _logger.success('✓ Written successfully to $flutterNativeSplashPath');
    }

    _logger.info('- Prepare config for package_rename_config_template');
    final packageNameConfigMapValues = {
      'app_name': application.name,
      'android_package_name': application.androidPlatformId,
      'ios_package_name': application.iosPlatformId,
      'override_old_package': 'com.webtrit.app',
      'description': '',
    };
    final packageNameConfigTemplate = Template(StringifyAssets.packageRenameConfigTemplate, htmlEscapeValues: false);
    final packageNameConfig = packageNameConfigTemplate.renderString(packageNameConfigMapValues);
    final packageNameConfigPath = _workingDirectory(configPathPackagePath);
    File(packageNameConfigPath).writeAsStringSync(packageNameConfig);
    _logger
      ..success('✓ Written successfully to $packageNameConfigPath')
      ..info('- Prepare config for $configureDartDefinePath');

    final httpsPrefix = application.coreUrl!.startsWith('https://') || application.coreUrl!.startsWith('http://');
    final url = httpsPrefix ? application.coreUrl! : 'https://${application.coreUrl!}';
    _logger.info('- Use $url as core');

    final isAppSalesEmailAvailable = (application.contactInfo?.appSalesEmail ?? '').isNotEmpty;
    final isDemoFlow = publisherAppDemoFlag || application.demo;
    final isClassicFlow = publisherAppClassicFlag && !application.demo;

    final dartDefineMapValues = {
      'WEBTRIT_APP_CORE_URL': isClassicFlow ? url : null,
      'WEBTRIT_APP_DEMO_CORE_URL': isDemoFlow ? url : null,
      'WEBTRIT_APP_SALES_EMAIL': isAppSalesEmailAvailable ? application.contactInfo?.appSalesEmail : null,
      'WEBTRIT_APP_NAME': null,
      'WEBTRIT_APP_GREETING': theme.texts?.greeting ?? application.name,
      'WEBTRIT_APP_DESCRIPTION': theme.texts?.greeting ?? '',
      'WEBTRIT_APP_TERMS_AND_CONDITIONS_URL': application.termsConditionsUrl,
      'WEBTRIT_ANDROID_RELEASE_UPLOAD_KEYSTORE_PATH': projectKeystoreDirectoryPath,
    };

    final dartDefineTemplate = Template(StringifyAssets.dartDefineTemplate, htmlEscapeValues: false, lenient: true);
    final dartDefine = dartDefineTemplate.renderStringFilteredJson(dartDefineMapValues);

    final dartDefinePath = _workingDirectory(configureDartDefinePath);
    File(dartDefinePath).writeAsStringSync(dartDefine);
    _logger
      ..success('✓ Written successfully to $dartDefinePath')
      ..info('- dart define appSalesEmailAvailable:$isClassicFlow')
      ..info('- dart define demo flow:$isDemoFlow')
      ..info('- dart define classic flow:$isClassicFlow')
      ..success('✓ Written successfully to $dartDefinePath');

    return ExitCode.success.code;
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
