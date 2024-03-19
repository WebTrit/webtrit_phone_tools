import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:dto/dto.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:simple_mustache/simple_mustache.dart';
import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';

const _publisherApplicationId = 'applicationId';

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
        _publisherApplicationId,
        help: 'Publisher application id',
        mandatory: true,
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
    ;
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

  @override
  Future<int> run() async {
    final commandArgResults = argResults!;

    final publisherApplicationId = commandArgResults[_publisherApplicationId] as String;
    if (publisherApplicationId.isEmpty) {
      _logger.err('Option "$_publisherApplicationId" can not be empty.');
      return ExitCode.usage.code;
    }

    final publisherAppDemoFlag = commandArgResults[_publisherAppDemoFlag] as bool;
    final publisherAppClassicFlag = commandArgResults[_publisherAppClassicFlag] as bool;

    late ApplicationDTO application;
    late ThemeDTO theme;

    try {
      final dartDefineTemplate = Mustache(map: {});

      final dartDefineStringJson = await dartDefineTemplate.convertFromFile(configureDartDefineTemplatePath);

      final url = '$configuratorApiUrl/api/v1/applications/$publisherApplicationId';
      application = await _loadData(url, ApplicationDTO.fromJsonString);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    if (application.theme == null) {
      _logger.err('Application $publisherApplicationId do not have default theme');
      return ExitCode.usage.code;
    }

    try {
      final url = '$configuratorApiUrl/api/v1/applications/$publisherApplicationId/themes/${application.theme}';
      theme = await _loadData(url, ThemeDTO.fromJsonString);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    final currentDirectory = Directory.current;
    final previousDirectory = path.dirname(currentDirectory.path);

    final platformIdentifier = application.platformIdentifier;

    final keystoreFolder = path.join(previousDirectory, 'webtrit_phone_keystores', platformIdentifier);

    final adaptiveIconBackground = await _loadFile(theme.images?.adaptiveIconBackground);
    _writeData(assetSplashIcon, adaptiveIconBackground);

    final adaptiveIconForeground = await _loadFile(theme.images?.adaptiveIconForeground);
    _writeData(assetLauncherIconAdaptiveForeground, adaptiveIconForeground);

    final webLauncherIcon = await _loadFile(theme.images?.webLauncherIcon);
    _writeData(assetLauncherWebIcon, webLauncherIcon);

    final androidLauncherIcon = await _loadFile(theme.images?.androidLauncherIcon);
    _writeData(assetLauncherAndroidIcon, androidLauncherIcon);

    final iosLauncherIcon = await _loadFile(theme.images?.iosLauncherIcon);
    _writeData(assetLauncherIosIcon, iosLauncherIcon);

    final notificationLogo = await _loadFile(theme.images?.notificationLogo);
    _writeData(assetIconIosNotificationTemplateImage, notificationLogo);

    final primaryOnboardingLogo = await _loadFile(theme.images?.primaryOnboardingLogo);
    _writeData(assetImagePrimaryOnboardingLogo, primaryOnboardingLogo);

    final secondaryOnboardingLogo = await _loadFile(theme.images?.secondaryOnboardingLogo);
    _writeData(assetImageSecondaryOnboardingLogo, secondaryOnboardingLogo);

    _writeData(assetThemePath, theme.toThemeSettingJsonString());

    final androidGoogleServices = await _loadFile(application.googleServices?.androidUrl);
    _writeData(googleServicesDestinationAndroid, androidGoogleServices);

    final iosGoogleServices = await _loadFile(application.googleServices?.iosUrl);
    _writeData(googleServiceDestinationIos, iosGoogleServices);

    if (theme.colors?.launch?.adaptiveIconBackground != null && theme.colors?.launch?.adaptiveIconBackground != null) {
      _logger.info('- Prepare config for flutter_launcher_icons_template');
      final flutterLauncherIconsMapValues = {
        'adaptive_icon_background': theme.colors?.launch?.adaptiveIconBackground,
        'theme_color': theme.colors?.launch?.adaptiveIconBackground
      };
      final flutterLauncherIconsTemplate = Mustache(map: flutterLauncherIconsMapValues);
      final flutterLauncherIcons = await flutterLauncherIconsTemplate.convertFromFile(configPathLaunchTemplate);
      _writeData(configPathLaunch, flutterLauncherIcons);
    }

    if (theme.colors?.launch?.splashBackground != null) {
      _logger.info('- Prepare config for flutter_native_splash_template');

      final flutterNativeSplashMapValues = {
        'background': theme.colors?.launch?.splashBackground?.replaceFirst('ff', '')
      };
      final flutterNativeSplashTemplate = Mustache(map: flutterNativeSplashMapValues);
      final flutterNativeSplash = await flutterNativeSplashTemplate.convertFromFile(configPathSplashTemplate);
      _writeData(configPathSplash, flutterNativeSplash);
    }

    _logger.info('- Prepare config for package_rename_config_template');
    final packageNameConfigMapValues = {
      'app_name': application.name!,
      'package_name': application.platformIdentifier!,
      'override_old_package': 'com.webtrit.app',
      'description': ''
    };
    final packageNameConfigTemplate = Mustache(map: packageNameConfigMapValues);
    final packageNameConfig = await packageNameConfigTemplate.convertFromFile(configPathPackageTemplate);
    _writeData(configPathPackage, packageNameConfig);

    // Configure dart define

    _logger.info('- Prepare config for $configureDartDefinePath');
    final httpsPrefix = application.coreUrl!.startsWith('https://') || application.coreUrl!.startsWith('http://');
    final url = httpsPrefix ? application.coreUrl! : 'https://${application.coreUrl!}';
    _logger.info('- Use $url as core');

    final dartDefineMapValues = {
      'APP_DEMO_CORE_URL': url,
      'APP_CORE_URL': url,
      'APP_NAME': application.name,
      'APP_GREETING': theme.texts?.greeting ?? application.name,
      'APP_DESCRIPTION': theme.texts?.greeting ?? '',
      'APP_TERMS_AND_CONDITIONS_URL': application.termsConditionsUrl,
      'APP_ANDROID_KEYSTORE': keystoreFolder,
    };
    final dartDefineTemplate = Mustache(map: dartDefineMapValues);

    final dartDefineStringJson = await dartDefineTemplate.convertFromFile(configureDartDefineTemplatePath);
    final dartDefineMap = jsonDecode(dartDefineStringJson) as Map;

    if (publisherAppDemoFlag) {
      _logger.warn('Use force demo flow');
      dartDefineMap.remove('WEBTRIT_APP_CORE_URL');
    } else if (publisherAppClassicFlag) {
      _logger.warn('Use force classic flow');
      dartDefineMap.remove('WEBTRIT_APP_DEMO_CORE_URL');
    } else if (application.demo) {
      _logger.warn('Use config demo flow');
      dartDefineMap.remove('WEBTRIT_APP_CORE_URL');
    } else {
      _logger.warn('Use config classic flow');
      dartDefineMap.remove('WEBTRIT_APP_DEMO_CORE_URL');
    }

    _writeData(configureDartDefinePath,
        (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(dartDefineMap))).toString());

    return ExitCode.success.code;
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

  void _writeData(String path, dynamic data) {
    if (data != null) {
      if (data is String) {
        File(Directory.current.path + path).writeAsStringSync(data);
      } else if (data is Uint8List) {
        File(Directory.current.path + path).writeAsBytesSync(data);
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