import 'dart:typed_data';

import 'package:mason_logger/mason_logger.dart';

import 'package:data/datasource/datasource.dart';

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
    await _writeColorScheme(applicationId, themeId, resolvePath);
    await _writePageConfig(applicationId, themeId, resolvePath);
    await _writeWidgetConfig(applicationId, themeId, resolvePath);
    await _writeAppConfigs(applicationId, themeId, resolvePath);
  }

  Future<void> _writeColorScheme(
    String applicationId,
    String themeId,
    String Function(String) resolvePath,
  ) async {
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
  }

  Future<void> _writePageConfig(
    String applicationId,
    String themeId,
    String Function(String) resolvePath,
  ) async {
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
  }

  Future<void> _writeWidgetConfig(
    String applicationId,
    String themeId,
    String Function(String) resolvePath,
  ) async {
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
  }

  Future<void> _writeAppConfigs(
    String applicationId,
    String themeId,
    String Function(String) resolvePath,
  ) async {
    final featureDto = await datasource.getFeatureAccessByTheme(
      applicationId: applicationId,
      themeId: themeId,
    );
    final embedsDto = await datasource.getEmbeds(applicationId);

    final migratedFeatures = await _migrateAssetsInJson(resolvePath, featureDto.config);
    await writeJsonToFile(resolvePath(assetAppConfigPath), migratedFeatures, logger: logger);

    final embedsList = embedsDto.map((e) => e.toJson()).toList();
    await writeJsonToFile(resolvePath(assetAppConfigEmbeddedsPath), embedsList, logger: logger);
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
