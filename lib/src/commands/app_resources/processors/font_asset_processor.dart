import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// Downloads the predefined Google Font selected by the generated theme.
class FontAssetProcessor {
  FontAssetProcessor({required Logger logger}) : _logger = logger;

  final Logger _logger;

  static const _ignoredFamilies = {'MaterialIcons'};
  static const _defaultWeights = [400, 500, 600, 700];

  /// How a weight is spelled in a font file's name.
  ///
  /// Not a choice: the app finds a bundled face by asking whether an asset's
  /// name ends with the one the `google_fonts` package builds, so a file named
  /// anything else is not found and the text renders in the platform font -
  /// silently, which is the worst way for this to be wrong. These are that
  /// package's own names.
  @visibleForTesting
  static const weightNames = <int, String>{
    100: 'Thin',
    200: 'ExtraLight',
    300: 'Light',
    400: 'Regular',
    500: 'Medium',
    600: 'SemiBold',
    700: 'Bold',
    800: 'ExtraBold',
    900: 'Black',
  };
  static const _httpTimeout = Duration(seconds: 30);

  Future<void> process({
    required Map<String, dynamic> lightConfig,
    required Map<String, dynamic> darkConfig,
    required String Function(String) resolvePath,
  }) async {
    // The theme declares its typeface in one place, `fonts.fontFamily`, and an
    // app carries exactly one. Collecting every `fontFamily` the configuration
    // mentions instead used to look equivalent and is not: the walk reaches into
    // anything nested, including the style of the initials drawn on an avatar
    // placeholder, and a value there was enough to refuse the whole build. Three
    // brands in production could not be built for that reason.
    final declared = <String>{
      for (final family in [_declaredFamily(lightConfig), _declaredFamily(darkConfig)])
        if (family != null) family,
    }..removeAll(_ignoredFamilies);

    if (declared.isEmpty) {
      _logger.warn('Theme declares no font family; leaving the app on its built-in typeface');
      return;
    }

    final family = declared.first;
    if (declared.length > 1) {
      // Light and dark are separate configurations and can drift apart. Until
      // the typeface belongs to the theme rather than to each appearance, the
      // light one is what a build carries - it is the one that gets edited.
      _logger.warn('Light and dark declare different fonts ($declared); building with $family');
    }
    final asked = {..._weights(lightConfig), ..._weights(darkConfig)};
    // Only the nine weights a font file can be named after. A theme asking for
    // anything else - 550, say - makes the service answer with the two weights
    // either side of it, which is more faces than were asked for and none of
    // them the one requested.
    final weights = asked.where(weightNames.containsKey).toSet();
    final unnameable = asked.difference(weights);
    if (unnameable.isNotEmpty) {
      _logger.warn('Ignoring weight(s) ${unnameable.join(', ')}: a font file can only be named after 100 to 900');
    }
    if (weights.isEmpty) {
      _logger.warn('No usable font weight in the theme; leaving the app on its built-in typeface');
      return;
    }
    final safeFamily = _safeFamily(family);
    final target = Directory(resolvePath(path.join('assets/fonts', safeFamily)));
    if (target.existsSync()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);

    final cssUri = Uri.https('fonts.googleapis.com', '/css2', {
      'family': '$family:wght@${weights.join(';')}',
    });
    final response = await http.get(cssUri, headers: const {'User-Agent': 'curl/8'}).timeout(_httpTimeout);
    if (response.statusCode != 200) {
      throw HttpException('Google Font $family lookup failed: ${response.statusCode}');
    }
    final entries = _parseCss(response.body);
    if (entries.isEmpty) {
      throw StateError('Google Font $family provided none of the weights ${weights.join(', ')}');
    }
    // A family need not have every weight - Alex Brush has one - and the service
    // answers with what it has. Refusing the lot over a missing face left the
    // brand with no typeface at all rather than with the faces that do exist.
    final delivered = entries.map((entry) => entry.weight).toSet();
    final absent = weights.difference(delivered);
    if (absent.isNotEmpty) {
      _logger.warn('$family has no ${absent.join(', ')}; the app will render those at the nearest weight it has');
    }
    for (final entry in entries) {
      final fontResponse = await http.get(Uri.parse(entry.url)).timeout(_httpTimeout);
      if (fontResponse.statusCode != 200) {
        throw HttpException('Google Font $family ${entry.weight} download failed: ${fontResponse.statusCode}');
      }
      final bytes = fontResponse.bodyBytes;
      if (bytes.isEmpty) {
        throw StateError('Downloaded empty font for $family ${entry.weight}');
      }
      final suffix = weightNames[entry.weight];
      if (suffix == null) {
        // Cannot happen from a weight this asked for - the request is filtered
        // to the nine the names cover - so this is the service answering with
        // something else, and guessing a name would bundle a file nothing looks
        // for.
        _logger.warn('Google Fonts answered with weight ${entry.weight}, which has no standard name; skipping it');
        continue;
      }
      await File(path.join(target.path, '$family-$suffix.ttf')).writeAsBytes(bytes);
    }
    final licenseResponse = await http
        .get(Uri.parse(
          'https://raw.githubusercontent.com/google/fonts/main/ofl/${_slug(family)}/OFL.txt',
        ))
        .timeout(_httpTimeout);
    if (licenseResponse.statusCode == 200) {
      await File(path.join(target.path, 'OFL.txt')).writeAsString(licenseResponse.body);
    } else {
      _logger.warn('License unavailable for $family (${licenseResponse.statusCode})');
    }
    _logger.info('Downloaded $family font assets (${entries.length} variants)');
  }

  /// The family the theme declares, not every family it happens to mention.
  String? _declaredFamily(Map<String, dynamic> config) {
    final fonts = config['fonts'];
    if (fonts is! Map) return null;
    final family = fonts['fontFamily'];
    if (family is! String) return null;
    final trimmed = family.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Set<int> _weights(Map<String, dynamic> config) {
    final result = <int>{};
    void visit(Object? value) {
      if (value is Map) {
        final weight = value['weight'];
        if (weight is int && weight >= 100 && weight <= 900) result.add(weight);
        value.values.forEach(visit);
      } else if (value is List) {
        value.forEach(visit);
      }
    }

    visit(config);
    return result.isEmpty ? _defaultWeights.toSet() : result;
  }

  List<({int weight, String url})> _parseCss(String css) {
    final pattern = RegExp(
      r'font-weight:\s*(\d+).*?src:\s*url\((https://fonts\.gstatic\.com/[^)]+\.ttf)\)',
      dotAll: true,
    );
    return pattern
        .allMatches(css)
        .map((match) => (
              weight: int.parse(match.group(1)!),
              url: match.group(2)!,
            ))
        .toList();
  }

  String _safeFamily(String family) {
    final valid = RegExp(r'^[\p{L}\p{N}][\p{L}\p{N} _-]*$', unicode: true).firstMatch(family)?.group(0) == family;
    if (!valid) {
      throw FormatException('Invalid Google Font family: $family');
    }
    return family.replaceAll(RegExp(r'\s+'), '_');
  }

  String _slug(String family) => family.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
