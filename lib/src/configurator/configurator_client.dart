import 'package:webtrit_phone_tools/src/utils/utils.dart';

import 'models.dart';

/// The configurator backend, as a build sees it: nine reads, no writes.
///
/// It speaks over the CLI's own `HttpClient` - the same retrying transport the
/// asset downloads and the translation bundles use - instead of the Dio stack
/// that came with the configurator's Flutter `data` package.
///
/// Every call carries its headers, so the token a command was given travels with
/// the whole run; there is no interceptor to forget to install.
class ConfiguratorClient {
  ConfiguratorClient({
    required HttpClient transport,
    Map<String, String> headers = const {},
  })  : _transport = transport,
        _headers = headers;

  final HttpClient _transport;
  final Map<String, String> _headers;

  /// The same client, speaking for whoever these headers name.
  ConfiguratorClient withHeaders(Map<String, String> headers) =>
      ConfiguratorClient(transport: _transport, headers: {..._headers, ...headers});

  Future<ApplicationInfo> getApplication(String applicationId) async {
    return ApplicationInfo.fromJson(await _map('/applications/$applicationId'));
  }

  Future<ThemeInfo> getTheme(String applicationId, String themeId) async {
    return ThemeInfo.fromJson(await _map('/applications/$applicationId/themes/$themeId'));
  }

  /// The feature-access configuration of a theme - what the app IS, as one
  /// JSON document the phone parses itself.
  Future<Map<String, dynamic>> getFeatureAccessConfig({
    required String applicationId,
    required String themeId,
  }) async {
    final response = await _map('/applications/$applicationId/feature-access/by-theme/$themeId');
    return _config(response);
  }

  /// Embedded resources of an application, passed through untouched.
  Future<List<Map<String, dynamic>>> getEmbeds(String applicationId) async {
    final list = await _transport.getJsonList('/applications/$applicationId/embeds', headers: _headers);
    return [
      for (final item in list)
        if (item is Map) {for (final entry in item.entries) '${entry.key}': entry.value},
    ];
  }

  Future<Map<String, dynamic>> getColorSchemeConfig({
    required String applicationId,
    required String themeId,
    required String variant,
  }) async {
    return _config(await _map('/applications/$applicationId/themes/$themeId/color-schemes/$variant'));
  }

  Future<Map<String, dynamic>> getPageConfig({
    required String applicationId,
    required String themeId,
    required String variant,
  }) async {
    return _config(await _map('/applications/$applicationId/themes/$themeId/page-configs/$variant'));
  }

  Future<Map<String, dynamic>> getWidgetConfig({
    required String applicationId,
    required String themeId,
    required String variant,
  }) async {
    return _config(await _map('/applications/$applicationId/themes/$themeId/widget-configs/$variant'));
  }

  Future<SplashAssets> getSplashAsset({
    required String applicationId,
    required String themeId,
  }) async {
    return SplashAssets.fromJson(await _map('/applications/$applicationId/themes/$themeId/splash-asset'));
  }

  Future<LaunchIcons> getLaunchAssets({
    required String applicationId,
    required String themeId,
  }) async {
    return LaunchIcons.fromJson(await _map('/applications/$applicationId/themes/$themeId/launch-assets'));
  }

  Future<Map<String, dynamic>> _map(String path) => _transport.getJsonMap(path, headers: _headers);

  /// Configuration endpoints wrap the document the phone reads in a `config`
  /// field; an answer without one is empty rather than a crash, because a
  /// brand with no widget overrides is a legitimate answer.
  Map<String, dynamic> _config(Map<String, dynamic> response) {
    final config = response['config'];
    return config is Map ? {for (final entry in config.entries) '${entry.key}': entry.value} : <String, dynamic>{};
  }
}
