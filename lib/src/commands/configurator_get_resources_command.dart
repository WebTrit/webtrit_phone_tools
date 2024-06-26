import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:dto/dto.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:simple_mustache/simple_mustache.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/gen/assets.dart';

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
  }) : _logger = logger {
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
      final url = '$configuratorApiUrl/api/v1/applications/$applicationId';
      application = await _loadData(url, ApplicationDTO.fromJsonString);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    if (application.theme == null) {
      _logger.err('Application $applicationId do not have default theme');
      return ExitCode.usage.code;
    }

    try {
      final url = '$configuratorApiUrl/api/v1/applications/$applicationId/themes/${application.theme}';
      theme = await _loadData(url, ThemeDTO.fromJsonString);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    try {
      final url = '$configuratorApiUrl/api/v1/translations/compose-arb/$applicationId';

      final translationsZip = await _loadFile(url);

      for (final file in ZipDecoder().decodeBytes(translationsZip!)) {
        final filename = file.name;
        final data = file.content;
        final outPath = _workingDirectory('$translationsArbPath/app_$filename');
        _writeData(path: outPath, data: data);
      }
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
            _logger.info('- Project ssl certificates directory credentials path not exists');
          }
        }
      }
    } else {
      _logger.warn('- Project ssl certificates directory path not exists');
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

    _writeData(
      path: _workingDirectory(cacheSessionDataPath),
      data: buildConfig.toJson(),
    );

    final adaptiveIconBackground = await _loadFile(theme.images?.adaptiveIconBackground);
    _writeData(
      path: _workingDirectory(assetSplashIconPath),
      data: adaptiveIconBackground,
    );

    final adaptiveIconForeground = await _loadFile(theme.images?.adaptiveIconForeground);
    _writeData(
      path: _workingDirectory(assetLauncherIconAdaptiveForegroundPath),
      data: adaptiveIconForeground,
    );

    final webLauncherIcon = await _loadFile(theme.images?.webLauncherIcon);
    _writeData(
      path: _workingDirectory(assetLauncherWebIconPath),
      data: webLauncherIcon,
    );

    final androidLauncherIcon = await _loadFile(theme.images?.androidLauncherIcon);
    _writeData(
      path: _workingDirectory(assetLauncherAndroidIconPath),
      data: androidLauncherIcon,
    );

    final iosLauncherIcon = await _loadFile(theme.images?.iosLauncherIcon);
    _writeData(
      path: _workingDirectory(assetLauncherIosIconPath),
      data: iosLauncherIcon,
    );

    final notificationLogo = await _loadFile(theme.images?.notificationLogo);
    _writeData(
      path: _workingDirectory(assetIconIosNotificationTemplateImagePath),
      data: notificationLogo,
    );

    final primaryOnboardingLogo = await _loadFile(theme.images?.primaryOnboardingLogo);
    _writeData(
      path: _workingDirectory(assetImagePrimaryOnboardingLogoPath),
      data: primaryOnboardingLogo,
    );

    final secondaryOnboardingLogo = await _loadFile(theme.images?.secondaryOnboardingLogo);
    _writeData(
      path: _workingDirectory(assetImageSecondaryOnboardingLogoPath),
      data: secondaryOnboardingLogo,
    );

    _writeData(
      path: _workingDirectory(assetThemePath),
      data: theme.toThemeSettingJsonString(),
    );

    if (theme.colors?.launch?.adaptiveIconBackground != null && theme.colors?.launch?.adaptiveIconBackground != null) {
      _logger.info('- Prepare config for flutter_launcher_icons_template');
      final flutterLauncherIconsMapValues = {
        'adaptive_icon_background': theme.colors?.launch?.adaptiveIconBackground,
        'theme_color': theme.colors?.launch?.adaptiveIconBackground,
      };
      final flutterLauncherIconsTemplate = Mustache(map: flutterLauncherIconsMapValues);
      final flutterLauncherIcons = flutterLauncherIconsTemplate.convert(StringifyAssets.flutterLauncherIconsTemplate);
      _writeData(
        path: _workingDirectory(configPathLaunchPath),
        data: flutterLauncherIcons,
      );
    }

    if (theme.colors?.launch?.splashBackground != null) {
      _logger.info('- Prepare config for flutter_native_splash_template');

      final flutterNativeSplashMapValues = {
        'background': theme.colors?.launch?.splashBackground?.replaceFirst('ff', ''),
      };
      final flutterNativeSplashTemplate = Mustache(map: flutterNativeSplashMapValues);
      final flutterNativeSplash = flutterNativeSplashTemplate.convert(StringifyAssets.flutterNativeSplashTemplate);
      _writeData(
        path: _workingDirectory(configPathSplashPath),
        data: flutterNativeSplash,
      );
    }

    _logger.info('- Prepare config for package_rename_config_template');
    final packageNameConfigMapValues = {
      'app_name': application.name,
      'android_package_name': application.androidPlatformId,
      'ios_package_name': application.iosPlatformId,
      'override_old_package': 'com.webtrit.app',
      'description': '',
    };
    final packageNameConfigTemplate = Mustache(map: packageNameConfigMapValues);
    final packageNameConfig = packageNameConfigTemplate.convert(StringifyAssets.packageRenameConfigTemplate);
    _writeData(
      path: _workingDirectory(configPathPackagePath),
      data: packageNameConfig,
    );

    // Configure dart define

    _logger.info('- Prepare config for $configureDartDefinePath');
    final httpsPrefix = application.coreUrl!.startsWith('https://') || application.coreUrl!.startsWith('http://');
    final url = httpsPrefix ? application.coreUrl! : 'https://${application.coreUrl!}';
    _logger.info('- Use $url as core');

    final appSalesEmailAvailable = (application.contactInfo?.appSalesEmail ?? '').isNotEmpty;
    final dartDefineMapValues = {
      'WEBTRIT_APP_DEMO_CORE_URL': url,
      'WEBTRIT_APP_CORE_URL': url,
      'WEBTRIT_APP_SALES_EMAIL': application.contactInfo?.appSalesEmail,
      'WEBTRIT_APP_NAME': application.name,
      'WEBTRIT_APP_GREETING': theme.texts?.greeting ?? application.name,
      'WEBTRIT_APP_DESCRIPTION': theme.texts?.greeting ?? '',
      'WEBTRIT_APP_TERMS_AND_CONDITIONS_URL': application.termsConditionsUrl,
      'WEBTRIT_ANDROID_RELEASE_UPLOAD_KEYSTORE_PATH': projectKeystoreDirectoryPath,
    };
    final dartDefineTemplate = Mustache(map: dartDefineMapValues);
    final dartDefine = dartDefineTemplate.convert(StringifyAssets.dartDefineTemplate).toMap();

    _logger.info('- dart define appSalesEmailAvailable:$appSalesEmailAvailable');

    // TODO(Serdun): Check if another implementation of mustache exists or add the possibility to handle these cases more easily.
    if (!appSalesEmailAvailable) {
      dartDefine.remove('WEBTRIT_APP_SALES_EMAIL');
    }
    // TODO(Serdun): Check if another implementation of mustache exists or add the possibility to handle these cases more easily.
    if (publisherAppDemoFlag) {
      _logger.warn('Use force demo flow');
      dartDefine.remove('WEBTRIT_APP_CORE_URL');
    } else if (publisherAppClassicFlag) {
      _logger.warn('Use force classic flow');
      dartDefine.remove('WEBTRIT_APP_DEMO_CORE_URL');
    } else if (application.demo) {
      _logger.warn('Use config demo flow');
      dartDefine.remove('WEBTRIT_APP_CORE_URL');
    } else {
      _logger.warn('Use config classic flow');
      dartDefine.remove('WEBTRIT_APP_DEMO_CORE_URL');
    }

    _writeData(
      path: _workingDirectory(configureDartDefinePath),
      data: dartDefine.toJson(),
    );

    return ExitCode.success.code;
  }

  String _workingDirectory(String relativePath) {
    return path.normalize(path.join(workingDirectoryPath, relativePath));
  }

  Future<T> _loadData<T>(String url, T Function(String) fromBody) async {
    final progress = _logger.progress('Loading data from $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        progress.complete('Data loaded successfully from $url');
        return fromBody(response.body);
      } else {
        progress.fail('Failed to load data from $url: ${response.statusCode}');
        throw Exception('Failed to load data from $url: ${response.statusCode}');
      }
    } catch (e) {
      progress.fail('Failed to load data from $url: $e');
      rethrow;
    }
  }

  void _writeData({
    required String path,
    required dynamic data,
  }) {
    if (data != null) {
      if (data is String) {
        File(path).writeAsStringSync(data);
      } else if (data is Uint8List) {
        File(path).writeAsBytesSync(data);
      }
      _logger.success('✓ Written successfully to $path');
    } else {
      _logger.err('✗ Field to write $path with $data');
    }
  }

  Future<Uint8List?> _loadFile(String? url) async {
    final progress = _logger.progress('Load file');
    if (url == null) {
      progress.fail('Failed to load file from null link');
      return null;
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        progress.complete('File get successfully from $url');
        return response.bodyBytes;
      } else {
        progress.fail('Failed to load file from $url: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      progress.fail('Failed to load file from $url: $e');
      return null;
    }
  }
}
