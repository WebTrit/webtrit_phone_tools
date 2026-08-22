import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/configurator/configurator.dart';

import '../constants/constants.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

class AssetProcessor {
  const AssetProcessor({
    required this.httpClient,
    required this.client,
    required this.logger,
  });

  final HttpClient httpClient;
  final ConfiguratorClient client;
  final Logger logger;

  Future<SplashAssets> processSplashAssets({
    required String applicationId,
    required String themeId,
    required String Function(String) resolvePath,
  }) async {
    final splash = await client.getSplashAsset(applicationId: applicationId, themeId: themeId);
    await _downloadAsset(splash.splashUrl, assetSplashIconPath, 'splash image', resolvePath);

    final android12Url = splash.android12SplashUrl;
    if (android12Url != null && android12Url.isNotEmpty) {
      await _downloadAsset(android12Url, assetAndroid12SplashIconPath, 'android 12 splash image', resolvePath);
    }

    return splash;
  }

  Future<LaunchIcons> processLaunchIcons({
    required String applicationId,
    required String themeId,
    required String Function(String) resolvePath,
  }) async {
    final icons = await client.getLaunchAssets(applicationId: applicationId, themeId: themeId);

    await Future.wait([
      _downloadAsset(icons.androidLegacyUrl, assetLauncherAndroidIconPath, 'android legacy icon', resolvePath),
      _downloadAsset(icons.androidAdaptiveForegroundUrl, assetLauncherIconAdaptiveForegroundPath,
          'android adaptive icon', resolvePath),
      _downloadAsset(icons.webUrl, assetLauncherWebIconPath, 'web icon', resolvePath),
      _downloadAsset(icons.iosUrl, assetLauncherIosIconPath, 'ios icon', resolvePath),
    ]);

    return icons;
  }

  Future<void> _downloadAsset(
    String? url,
    String relativePath,
    String label,
    String Function(String) resolvePath,
  ) async {
    if (url == null || url.isEmpty) {
      logger.warn('Skip $label: empty URL');
      return;
    }

    try {
      final bytes = await httpClient.getBytes(url);
      if (bytes != null) {
        final file = File(resolvePath(relativePath));
        if (!file.parent.existsSync()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsBytes(bytes);
        logger.success('✓ Downloaded $label');
      } else {
        logger.err('✗ Failed to download $label from $url');
      }
    } catch (e) {
      logger.err('✗ Error downloading $label: $e');
    }
  }
}
