import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/configurator/configurator.dart';
import 'package:webtrit_appearance_theme/webtrit_appearance_theme.dart';

import '../constants/constants.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';
import 'font_asset_processor.dart';

class ThemeConfigProcessor {
  ThemeConfigProcessor({
    required this.httpClient,
    required this.client,
    required this.logger,
    FontAssetProcessor? fontAssetProcessor,
  }) : fontAssetProcessor = fontAssetProcessor ?? FontAssetProcessor(logger: logger);

  final HttpClient httpClient;
  final ConfiguratorClient client;
  final Logger logger;

  /// Downloads the font the theme selects. It reaches Google Fonts, so a run
  /// that must stay offline supplies its own.
  final FontAssetProcessor fontAssetProcessor;

  static const _imagesAssetDiskDir = 'assets/images';
  static const _imagesAssetLogicalPrefix = 'asset://assets/images';

  Future<void> process({
    required String applicationId,
    required String themeId,
    required String Function(String) resolvePath,
  }) async {
    // 1. Fetch feature-access + embeds and write app configs first
    final featureConfig = await client.getFeatureAccessConfig(
      applicationId: applicationId,
      themeId: themeId,
    );
    final embeds = await client.getEmbeds(applicationId);

    final migratedFeatures = await _migrateAssetsInJson(resolvePath, featureConfig);
    await writeJsonToFile(resolvePath(assetAppConfigPath), migratedFeatures, logger: logger);

    await writeJsonToFile(resolvePath(assetAppConfigEmbeddedsPath), embeds, logger: logger);

    // 2. Resolve which theme variants to fetch based on themeMode
    final appConfig = AppConfig.fromJson(featureConfig);
    final themeMode = appConfig.supported.whereType<SupportedThemeMode>().firstOrNull;
    final variants = _resolveVariants(themeMode);

    logger
      ..info('Theme mode: ${themeMode?.mode.name ?? 'not set (defaulting to light)'}')
      ..info('Variants to fetch: ${variants.join(', ')}');
    if (variants.length == 1) {
      logger.info('Single variant mode — ${variants.first} config will be written to both light and dark files');
    }

    // 3. Write theme configs fetching only needed variants
    await _writeColorScheme(applicationId, themeId, resolvePath, variants);
    await _writePageConfig(applicationId, themeId, resolvePath, variants);
    await _writeWidgetConfig(applicationId, themeId, resolvePath, variants);

    // The brand font is fetched from a public font service, so this is the one
    // step here that a network of its own can refuse. It is also the one whose
    // absence the app survives - it falls back to a substituted face - so a
    // refusal is said out loud rather than ending a run that has already
    // written everything the app needs to behave correctly.
    try {
      await fontAssetProcessor.process(
        lightConfig: Map<String, dynamic>.from(
          jsonDecode(await File(resolvePath(assetWidgetsLightConfig)).readAsString()) as Map,
        ),
        darkConfig: Map<String, dynamic>.from(
          jsonDecode(await File(resolvePath(assetWidgetsDarkConfig)).readAsString()) as Map,
        ),
        resolvePath: resolvePath,
      );
    } catch (e, s) {
      logger
        ..err('Could not fetch the brand font: $e')
        ..err('  -> the app will be built with a substituted typeface.')
        ..err('  -> Everything else was generated. Fix this and run again.')
        ..detail('$s');
    }
  }

  /// Determines which theme variants (light/dark) to fetch from the backend
  /// based on [SupportedThemeMode] from [AppConfig.supported].
  ///
  /// Returns:
  /// - `["light", "dark"]` when mode is [ThemeModeConfig.system].
  /// - `["dark"]` when mode is [ThemeModeConfig.dark] — only dark exists on the backend.
  /// - `["light"]` when mode is [ThemeModeConfig.light] or [themeMode] is null.
  List<String> _resolveVariants(SupportedThemeMode? themeMode) {
    if (themeMode == null) return ['light'];
    return switch (themeMode.mode) {
      ThemeModeConfig.system => ['light', 'dark'],
      ThemeModeConfig.dark => ['dark'],
      ThemeModeConfig.light => ['light'],
    };
  }

  Future<void> _writeColorScheme(
    String applicationId,
    String themeId,
    String Function(String) resolvePath,
    List<String> variants,
  ) async {
    if (variants.contains('light') && variants.contains('dark')) {
      final lightConfig = await client.getColorSchemeConfig(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'light',
      );
      await writeJsonToFile(resolvePath(assetLightColorSchemePath), lightConfig, logger: logger);

      final darkConfig = await client.getColorSchemeConfig(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'dark',
      );
      await writeJsonToFile(resolvePath(assetDarkColorSchemePath), darkConfig, logger: logger);
    } else {
      final variant = variants.first;
      final config = await client.getColorSchemeConfig(
        applicationId: applicationId,
        themeId: themeId,
        variant: variant,
      );
      await writeJsonToFile(resolvePath(assetLightColorSchemePath), config, logger: logger);
      await writeJsonToFile(resolvePath(assetDarkColorSchemePath), config, logger: logger);
    }
  }

  Future<void> _writePageConfig(
    String applicationId,
    String themeId,
    String Function(String) resolvePath,
    List<String> variants,
  ) async {
    if (variants.contains('light') && variants.contains('dark')) {
      final lightConfig = await client.getPageConfig(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'light',
      );
      final migratedLight = await _migrateAssetsInJson(resolvePath, lightConfig);
      await writeJsonToFile(resolvePath(assetPageLightConfig), migratedLight, logger: logger);

      final darkConfig = await client.getPageConfig(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'dark',
      );
      final migratedDark = await _migrateAssetsInJson(resolvePath, darkConfig);
      await writeJsonToFile(resolvePath(assetPageDarkConfig), migratedDark, logger: logger);
    } else {
      final variant = variants.first;
      final config = await client.getPageConfig(
        applicationId: applicationId,
        themeId: themeId,
        variant: variant,
      );
      final migrated = await _migrateAssetsInJson(resolvePath, config);
      await writeJsonToFile(resolvePath(assetPageLightConfig), migrated, logger: logger);
      await writeJsonToFile(resolvePath(assetPageDarkConfig), migrated, logger: logger);
    }
  }

  Future<void> _writeWidgetConfig(
    String applicationId,
    String themeId,
    String Function(String) resolvePath,
    List<String> variants,
  ) async {
    if (variants.contains('light') && variants.contains('dark')) {
      final lightConfig = await client.getWidgetConfig(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'light',
      );
      final migratedLight = await _migrateAssetsInJson(resolvePath, lightConfig);
      await writeJsonToFile(resolvePath(assetWidgetsLightConfig), migratedLight, logger: logger);

      final darkConfig = await client.getWidgetConfig(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'dark',
      );
      final migratedDark = await _migrateAssetsInJson(resolvePath, darkConfig);
      await writeJsonToFile(resolvePath(assetWidgetsDarkConfig), migratedDark, logger: logger);
    } else {
      final variant = variants.first;
      final config = await client.getWidgetConfig(
        applicationId: applicationId,
        themeId: themeId,
        variant: variant,
      );
      final migrated = await _migrateAssetsInJson(resolvePath, config);
      await writeJsonToFile(resolvePath(assetWidgetsLightConfig), migrated, logger: logger);
      await writeJsonToFile(resolvePath(assetWidgetsDarkConfig), migrated, logger: logger);
    }
  }

  Future<Map<String, dynamic>> _migrateAssetsInJson(
    String Function(String) resolvePath,
    Map<String, dynamic> json,
  ) async {
    Future<Uint8List?> fetchBytesAdapter(String url) async {
      final List<int>? bytes = await httpClient.getBytes(url);
      return bytes is Uint8List ? bytes : (bytes != null ? Uint8List.fromList(bytes) : null);
    }

    final migrator = JsonAssetMigrator(
      fetchBytes: fetchBytesAdapter,
      assetsRootOnDisk: resolvePath(_imagesAssetDiskDir),
      assetLogicalPrefix: _imagesAssetLogicalPrefix,
      logger: logger,
    );

    final result = await migrator.transform(json);
    return Map<String, dynamic>.from(result as Map);
  }
}
