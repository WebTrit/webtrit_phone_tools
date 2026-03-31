import 'dart:typed_data';

import 'package:mason_logger/mason_logger.dart';

import 'package:data/datasource/datasource.dart';
import 'package:webtrit_appearance_theme/webtrit_appearance_theme.dart';

import '../constants/constants.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

class ThemeConfigProcessor {
  const ThemeConfigProcessor({
    required this.httpClient,
    required this.datasource,
    required this.logger,
  });

  final HttpClient httpClient;
  final ConfiguratorBackandDatasource datasource;
  final Logger logger;

  static const _imagesAssetDiskDir = 'assets/images';
  static const _imagesAssetLogicalPrefix = 'asset://assets/images';

  Future<void> process({
    required String applicationId,
    required String themeId,
    required String Function(String) resolvePath,
  }) async {
    // 1. Fetch feature-access + embeds and write app configs first
    final featureDto = await datasource.getFeatureAccessByTheme(
      applicationId: applicationId,
      themeId: themeId,
    );
    final embedsDto = await datasource.getEmbeds(applicationId);

    final migratedFeatures = await _migrateAssetsInJson(resolvePath, featureDto.config);
    await writeJsonToFile(resolvePath(assetAppConfigPath), migratedFeatures, logger: logger);

    final embedsList = embedsDto.map((e) => e.toJson()).toList();
    await writeJsonToFile(resolvePath(assetAppConfigEmbeddedsPath), embedsList, logger: logger);

    // 2. Resolve which theme variants to fetch based on themeMode
    final appConfig = AppConfig.fromJson(featureDto.config);
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
      final lightDto = await datasource.getColorSchemeByVariant(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'light',
      );
      await writeJsonToFile(resolvePath(assetLightColorSchemePath), lightDto.config, logger: logger);

      final darkDto = await datasource.getColorSchemeByVariant(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'dark',
      );
      await writeJsonToFile(resolvePath(assetDarkColorSchemePath), darkDto.config, logger: logger);
    } else {
      final variant = variants.first;
      final dto = await datasource.getColorSchemeByVariant(
        applicationId: applicationId,
        themeId: themeId,
        variant: variant,
      );
      await writeJsonToFile(resolvePath(assetLightColorSchemePath), dto.config, logger: logger);
      await writeJsonToFile(resolvePath(assetDarkColorSchemePath), dto.config, logger: logger);
    }
  }

  Future<void> _writePageConfig(
    String applicationId,
    String themeId,
    String Function(String) resolvePath,
    List<String> variants,
  ) async {
    if (variants.contains('light') && variants.contains('dark')) {
      final lightDto = await datasource.getPageConfigByThemeVariant(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'light',
      );
      final migratedLight = await _migrateAssetsInJson(resolvePath, lightDto.config);
      await writeJsonToFile(resolvePath(assetPageLightConfig), migratedLight, logger: logger);

      final darkDto = await datasource.getPageConfigByThemeVariant(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'dark',
      );
      final migratedDark = await _migrateAssetsInJson(resolvePath, darkDto.config);
      await writeJsonToFile(resolvePath(assetPageDarkConfig), migratedDark, logger: logger);
    } else {
      final variant = variants.first;
      final dto = await datasource.getPageConfigByThemeVariant(
        applicationId: applicationId,
        themeId: themeId,
        variant: variant,
      );
      final migrated = await _migrateAssetsInJson(resolvePath, dto.config);
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
      final lightDto = await datasource.getWidgetConfigByThemeVariant(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'light',
      );
      final migratedLight = await _migrateAssetsInJson(resolvePath, lightDto.config);
      await writeJsonToFile(resolvePath(assetWidgetsLightConfig), migratedLight, logger: logger);

      final darkDto = await datasource.getWidgetConfigByThemeVariant(
        applicationId: applicationId,
        themeId: themeId,
        variant: 'dark',
      );
      final migratedDark = await _migrateAssetsInJson(resolvePath, darkDto.config);
      await writeJsonToFile(resolvePath(assetWidgetsDarkConfig), migratedDark, logger: logger);
    } else {
      final variant = variants.first;
      final dto = await datasource.getWidgetConfigByThemeVariant(
        applicationId: applicationId,
        themeId: themeId,
        variant: variant,
      );
      final migrated = await _migrateAssetsInJson(resolvePath, dto.config);
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
