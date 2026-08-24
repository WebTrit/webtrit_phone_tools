/// Everything one build of one brand needs, as the service hands it over.
///
/// This used to be assembled here from nine separate calls through the
/// configurator's own client, which meant the tooling had to know the shape of
/// every slice, which theme to ask for, and where each file belongs in a
/// checkout. All of that is the service's knowledge, and it now says so in one
/// answer: the paths are its keys, the addresses are beside the files they
/// fill, and a build only has to write what it is given.
library;

class BuildBundle {
  const BuildBundle({
    required this.themeId,
    required this.application,
    required this.files,
    required this.assets,
    required this.brandImages,
    required this.font,
    required this.locales,
  });

  factory BuildBundle.fromJson(Map<String, dynamic> json) {
    return BuildBundle(
      themeId: json['themeId'] as String? ?? '',
      application: BundleApplication.fromJson(
        (json['application'] as Map<String, dynamic>?) ?? const {},
      ),
      files: (json['files'] as Map?)?.cast<String, dynamic>() ?? const {},
      assets: ((json['assets'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BundleAsset.fromJson)
          .toList(growable: false),
      brandImages: BrandImages.fromJson(
        (json['brandImages'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      font: (json['font'] as Map?) == null ? null : BundleFont.fromJson((json['font'] as Map).cast<String, dynamic>()),
      locales: (((json['translations'] as Map?)?['locales'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  final String themeId;
  final BundleApplication application;

  /// Documents to write, keyed by the path in the checkout each belongs to.
  final Map<String, dynamic> files;

  /// The pictures those documents point at, and where to fetch each from.
  final List<BundleAsset> assets;

  final BrandImages brandImages;
  final BundleFont? font;
  final List<String> locales;
}

/// The fields of an application a build reads. Nothing more of it is carried,
/// so nothing more of it can be depended on by accident.
class BundleApplication {
  const BundleApplication({
    this.id,
    this.name,
    this.androidPlatformId,
    this.iosPlatformId,
    this.androidLaunchName,
    this.iosLaunchName,
    this.androidVersion,
    this.iosVersion,
    this.environment = const {},
  });

  factory BundleApplication.fromJson(Map<String, dynamic> json) {
    return BundleApplication(
      id: json['id'] as String?,
      name: json['name'] as String?,
      androidPlatformId: json['androidPlatformId'] as String?,
      iosPlatformId: json['iosPlatformId'] as String?,
      androidLaunchName: json['androidLaunchName'] as String?,
      iosLaunchName: json['iosLaunchName'] as String?,
      androidVersion: BundleVersion.maybeFrom(json['androidVersion']),
      iosVersion: BundleVersion.maybeFrom(json['iosVersion']),
      environment: (json['environment'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  final String? id;
  final String? name;
  final String? androidPlatformId;
  final String? iosPlatformId;

  /// What goes under the icon, per store.
  ///
  /// [name] used to be this as well as the label the operator files the brand
  /// under in the configurator - one field, so renaming the one renamed the
  /// other. They are separate now, and a brand that has not been given a
  /// caption of its own still gets [name], which is what every build has used
  /// so far.
  final String? androidLaunchName;
  final String? iosLaunchName;

  final BundleVersion? androidVersion;
  final BundleVersion? iosVersion;
  final Map<String, dynamic> environment;

  /// The caption for one store, or the brand's name when it has none.
  String launchNameFor(BuildPlatform platform) {
    final chosen = platform == BuildPlatform.android ? androidLaunchName : iosLaunchName;
    return (chosen?.trim().isNotEmpty ?? false) ? chosen!.trim() : (name ?? '');
  }
}

/// The stores a build is made for.
enum BuildPlatform { android, ios }

class BundleVersion {
  const BundleVersion({this.buildName, this.buildNumber});

  static BundleVersion? maybeFrom(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    return BundleVersion(
      buildName: json['buildName'] as String?,
      buildNumber: (json['buildNumber'] as num?)?.toInt(),
    );
  }

  final String? buildName;
  final int? buildNumber;
}

class BundleAsset {
  const BundleAsset({required this.id, required this.path, required this.url});

  factory BundleAsset.fromJson(Map<String, dynamic> json) => BundleAsset(
        id: json['id'] as String? ?? '',
        path: json['path'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  final String id;

  /// Where the build writes the bytes.
  final String path;

  /// A short-lived address to fetch them from.
  final String url;
}

class BrandImages {
  const BrandImages({required this.splash, required this.launcher});

  factory BrandImages.fromJson(Map<String, dynamic> json) => BrandImages(
        splash: BrandImageSet.fromJson((json['splash'] as Map?)?.cast<String, dynamic>() ?? const {}),
        launcher: BrandImageSet.fromJson((json['launcher'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );

  final BrandImageSet splash;
  final BrandImageSet launcher;
}

class BrandImageSet {
  const BrandImageSet({this.backgroundColorHex, this.files = const []});

  factory BrandImageSet.fromJson(Map<String, dynamic> json) => BrandImageSet(
        backgroundColorHex: json['backgroundColorHex'] as String?,
        files: ((json['files'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((file) => BrandImageFile(
                  path: file['path'] as String? ?? '',
                  url: file['url'] as String? ?? '',
                ))
            .toList(growable: false),
      );

  final String? backgroundColorHex;
  final List<BrandImageFile> files;

  bool get isEmpty => files.isEmpty;

  /// Whether one of the images is meant for a particular file, which is how a
  /// generator asks "is there an Android 12 splash".
  bool writesTo(String path) => files.any((file) => file.path == path);
}

class BrandImageFile {
  const BrandImageFile({required this.path, required this.url});

  final String path;
  final String url;
}

class BundleFont {
  const BundleFont({this.family, this.weights = const []});

  factory BundleFont.fromJson(Map<String, dynamic> json) => BundleFont(
        family: json['family'] as String?,
        weights:
            ((json['weights'] as List?) ?? const []).whereType<num>().map((w) => w.toInt()).toList(growable: false),
      );

  final String? family;
  final List<int> weights;
}
