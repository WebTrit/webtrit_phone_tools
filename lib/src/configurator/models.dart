/// The slices of the configurator API this CLI reads.
///
/// Deliberately hand-written and deliberately partial. The configurator's own
/// `data` package models the whole API for a Flutter application, and a build
/// tool that imported it dragged Firebase plugins, a second HTTP stack and two
/// sibling repositories - one of them private - into a pure Dart command line.
/// What the build actually needs is the handful of fields below, so they live
/// here, next to the code that reads them, and unknown fields are ignored
/// rather than modelled.
library;

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : (value is num ? value.toInt() : null);

Map<String, String>? _stringMap(Object? value) {
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.value is String) '${entry.key}': entry.value as String,
  };
}

Map<String, dynamic> _jsonMap(Object? value) =>
    value is Map ? {for (final entry in value.entries) '${entry.key}': entry.value} : <String, dynamic>{};

/// A platform's version pair, as the build cache and the stores need it.
class BuildVersion {
  const BuildVersion({this.buildName, this.buildNumber});

  factory BuildVersion.fromJson(Map<String, dynamic> json) => BuildVersion(
    buildName: _string(json['buildName']),
    buildNumber: _int(json['buildNumber']),
  );

  final String? buildName;
  final int? buildNumber;
}

/// What a brand's application says about itself. `theme` names its default
/// theme - the build refuses to continue without one.
class ApplicationInfo {
  const ApplicationInfo({
    this.id,
    this.name,
    this.environment,
    this.iosPlatformId,
    this.androidPlatformId,
    this.androidVersion,
    this.iosVersion,
    this.theme,
  });

  factory ApplicationInfo.fromJson(Map<String, dynamic> json) => ApplicationInfo(
    id: _string(json['id']),
    name: _string(json['name']),
    environment: json['environment'] is Map ? _jsonMap(json['environment']) : null,
    iosPlatformId: _string(json['iosPlatformId']),
    androidPlatformId: _string(json['androidPlatformId']),
    androidVersion: json['androidVersion'] is Map ? BuildVersion.fromJson(_jsonMap(json['androidVersion'])) : null,
    iosVersion: json['iosVersion'] is Map ? BuildVersion.fromJson(_jsonMap(json['iosVersion'])) : null,
    theme: _string(json['theme']),
  );

  final String? id;
  final String? name;

  /// The dart-defines a build is handed, as the configurator stored them.
  final Map<String, dynamic>? environment;
  final String? iosPlatformId;
  final String? androidPlatformId;
  final BuildVersion? androidVersion;
  final BuildVersion? iosVersion;

  /// Identifier of the application's default theme.
  final String? theme;
}

/// Only the identity is read: everything a theme carries arrives through the
/// configuration and asset endpoints keyed by this id.
class ThemeInfo {
  const ThemeInfo({this.id});

  factory ThemeInfo.fromJson(Map<String, dynamic> json) => ThemeInfo(id: _string(json['id']));

  final String? id;
}

/// The splash screen a brand chose: the rendered images, and the colour the
/// generators paint behind them.
///
/// An answer that does not identify the theme it belongs to is refused rather
/// than read as "no splash": production has served such answers, and a brand
/// silently built with the stock WebTrit splash is worse than a brand told so.
class SplashAssets {
  const SplashAssets({this.urls, this.backgroundColorHex});

  factory SplashAssets.fromJson(Map<String, dynamic> json) {
    for (final key in ['id', 'applicationId', 'themeId']) {
      if (_string(json[key]) == null) {
        throw FormatException('The splash asset answer carries no "$key"');
      }
    }
    return SplashAssets(
      urls: _stringMap(json['urls']),
      backgroundColorHex: _string(_jsonMap(json['source'])['backgroundColorHex']),
    );
  }

  final Map<String, String>? urls;
  final String? backgroundColorHex;

  String? get splashUrl => urls?['splashUrl'];

  String? get android12SplashUrl => urls?['android12SplashUrl'];
}

/// The launcher icons a brand chose, one URL per platform slot.
///
/// The icons live inside an `entity` envelope; an answer without it is the
/// shape production served when a brand had none, and it is refused here for
/// the same reason the splash answer above is.
class LaunchIcons {
  const LaunchIcons({this.urls, this.backgroundColorHex});

  factory LaunchIcons.fromJson(Map<String, dynamic> json) {
    if (json['entity'] is! Map) {
      throw const FormatException('The launch assets answer carries no "entity"');
    }
    return LaunchIcons(
      urls: _stringMap(json['urls']),
      backgroundColorHex: _string(_jsonMap(_jsonMap(json['entity'])['source'])['backgroundColorHex']),
    );
  }

  final Map<String, String>? urls;
  final String? backgroundColorHex;

  String? get androidLegacyUrl => urls?['androidLegacyUrl'];

  String? get androidAdaptiveForegroundUrl => urls?['androidAdaptiveForegroundUrl'];

  String? get iosUrl => urls?['iosUrl'];

  String? get webUrl => urls?['webUrl'];
}
