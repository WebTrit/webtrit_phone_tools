import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:archive/archive.dart';

class HttpClient {
  HttpClient(this.baseUrl, this.logger);

  static const _maxRetries = 3;
  static const _retryDelaysMs = [5000, 15000, 30000];
  static final _random = Random();

  final String baseUrl;
  final Logger logger;

  String _translationsUrl(String applicationId) {
    return '$baseUrl/translations/compose-arb/$applicationId';
  }

  String get _catalogTranslationsUrl {
    return '$baseUrl/translations/catalog/arb';
  }

  /// A JSON object from a path under [baseUrl]. The typed reads of the
  /// configurator API are built on this, so they inherit the retries.
  Future<Map<String, dynamic>> getJsonMap(String path, {Map<String, String>? headers}) async {
    final decoded = await _fetchData<Object?>(
      _url(path),
      (response) => jsonDecode(utf8.decode(response.bodyBytes)),
      headers: headers,
    );
    if (decoded is! Map) {
      throw Exception('Expected a JSON object from $path');
    }
    return {for (final entry in decoded.entries) '${entry.key}': entry.value};
  }

  /// A JSON array from a path under [baseUrl].
  Future<List<dynamic>> getJsonList(String path, {Map<String, String>? headers}) async {
    final decoded = await _fetchData<Object?>(
      _url(path),
      (response) => jsonDecode(utf8.decode(response.bodyBytes)),
      headers: headers,
    );
    if (decoded is! List) {
      throw Exception('Expected a JSON array from $path');
    }
    return decoded;
  }

  String _url(String path) => path.startsWith('http') ? path : '$baseUrl$path';

  /// The composed ARB bundle for one application: the catalog with that
  /// application's overrides applied.
  ///
  /// [headers] carries the same credential the build bundle is fetched with a
  /// few lines earlier in the same command. The route does not require it yet -
  /// it is `@Public()` on the backend, from when a build pipeline had no
  /// machine credential to present - so sending it changes nothing today and
  /// lets that door be closed without breaking this caller.
  Future<Archive> getTranslationFiles(String applicationId, {Map<String, String>? headers}) async {
    final url = _translationsUrl(applicationId);
    final fileBytes = await getBytes(url, headers: headers);
    if (fileBytes != null) {
      return ZipDecoder().decodeBytes(fileBytes);
    } else {
      throw Exception('Failed to load file from $url');
    }
  }

  /// The whole global translation catalog, one `<locale>.arb` per shipped
  /// locale. Unlike the per-application bundle above this route needs a
  /// signed-in principal - the build pipeline's token.
  Future<Archive> getCatalogTranslationFiles({required Map<String, String> headers}) async {
    final url = _catalogTranslationsUrl;
    final fileBytes = await getBytes(url, headers: headers);
    if (fileBytes != null) {
      return ZipDecoder().decodeBytes(fileBytes);
    } else {
      throw Exception('Failed to load file from $url');
    }
  }

  Future<Uint8List?> getBytes(String? url, {Map<String, String>? headers}) async {
    if (url == null) {
      logger.err('Failed to load file from null link');
      return null;
    }
    return _fetchData<Uint8List>(
      url,
      (response) => response.bodyBytes,
      headers: headers,
    );
  }

  /// One brand's whole build input, as JSON. The address of the route is the
  /// service's business; what a caller supplies is which brand and how it is
  /// entitled to ask.
  Future<Map<String, dynamic>> getBuildBundle(
    String applicationId, {
    required Map<String, String> headers,
  }) async {
    return _fetchData<Map<String, dynamic>>(
      '$baseUrl/build/applications/$applicationId/bundle',
      (response) => jsonDecode(response.body) as Map<String, dynamic>,
      headers: headers,
    );
  }

  Future<T> _fetchData<T>(
    String url,
    T Function(http.Response response) parseResponse, {
    Map<String, String>? headers,
  }) async {
    final progress = logger.progress('Loading data from $url');

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        if (response.statusCode == 200) {
          progress.complete('Data loaded successfully from $url');
          return parseResponse(response);
        } else if (_isServerError(response.statusCode) && attempt < _maxRetries) {
          final delay = _delayWithJitter(_retryDelaysMs[attempt]);
          logger.detail(
              'Retry ${attempt + 1}/$_maxRetries for $url (status ${response.statusCode}), waiting ${delay.inMilliseconds}ms');
          await Future<void>.delayed(delay);
          continue;
        } else {
          final errorMessage = 'Failed to load data from $url: ${response.statusCode} ${response.reasonPhrase}';
          progress.fail(errorMessage);
          throw Exception(errorMessage);
        }
      } on http.ClientException catch (e) {
        if (attempt < _maxRetries) {
          final delay = _delayWithJitter(_retryDelaysMs[attempt]);
          logger.detail('Retry ${attempt + 1}/$_maxRetries for $url ($e), waiting ${delay.inMilliseconds}ms');
          await Future<void>.delayed(delay);
          continue;
        }
        final errorMessage = 'Failed to load data from $url: $e';
        progress.fail(errorMessage);
        throw Exception(errorMessage);
      } catch (e) {
        final errorMessage = 'Failed to load data from $url: $e';
        progress.fail(errorMessage);
        throw Exception(errorMessage);
      }
    }

    throw Exception('Failed to load data from $url after $_maxRetries retries');
  }

  /// Adds random jitter (0-50% of base delay) to spread parallel retries.
  static Duration _delayWithJitter(int baseDelayMs) {
    final jitter = _random.nextInt(baseDelayMs ~/ 2);
    return Duration(milliseconds: baseDelayMs + jitter);
  }

  static bool _isServerError(int statusCode) => statusCode >= 500;
}
