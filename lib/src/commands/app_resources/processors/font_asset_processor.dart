import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// Downloads the predefined Google Font selected by the generated theme.
class FontAssetProcessor {
  FontAssetProcessor({required Logger logger}) : _logger = logger;

  final Logger _logger;

  static const _ignoredFamilies = {'MaterialIcons'};
  static const _defaultWeights = [400, 500, 600, 700];
  static const _httpTimeout = Duration(seconds: 30);

  Future<void> process({
    required Map<String, dynamic> lightConfig,
    required Map<String, dynamic> darkConfig,
    required String Function(String) resolvePath,
  }) async {
    final families = {
      ..._families(lightConfig),
      ..._families(darkConfig),
    }..removeAll(_ignoredFamilies);
    if (families.length != 1) {
      throw StateError('Theme must select exactly one predefined Google Font: $families');
    }

    final family = families.single;
    final weights = {..._weights(lightConfig), ..._weights(darkConfig)};
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
    if (entries.length != weights.length) {
      throw StateError('Google Font $family does not provide all required weights');
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
      final suffix = switch (entry.weight) {
        400 => 'Regular',
        500 => 'Medium',
        600 => 'SemiBold',
        700 => 'Bold',
        _ => throw StateError('Unsupported weight ${entry.weight}'),
      };
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

  Set<String> _families(Map<String, dynamic> config) {
    final result = <String>{};
    void visit(Object? value) {
      if (value is Map) {
        final family = value['fontFamily'];
        if (family is String && family.trim().isNotEmpty) {
          result.add(family.trim());
        }
        value.values.forEach(visit);
      } else if (value is List) {
        value.forEach(visit);
      }
    }

    visit(config);
    return result;
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
