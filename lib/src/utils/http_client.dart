import 'dart:typed_data';

import 'package:data/dto/application/application.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:archive/archive.dart';

class HttpClient {
  HttpClient(this.baseUrl, this.logger);

  static const _maxRetries = 3;
  static const _retryDelaysMs = [2000, 4000, 8000];

  final String baseUrl;
  final Logger logger;

  String _applicationUrl(String applicationId) {
    return '$baseUrl/api/v1/applications/$applicationId';
  }

  String _translationsUrl(String applicationId) {
    return '$baseUrl/api/v1/translations/compose-arb/$applicationId';
  }

  Future<ApplicationDTO> getApplication(String applicationId) async {
    final url = _applicationUrl(applicationId);
    return _fetchData<ApplicationDTO>(
      url,
      (response) => ApplicationDTO.fromJsonString(response.body),
    );
  }

  Future<Archive> getTranslationFiles(String applicationId) async {
    final url = _translationsUrl(applicationId);
    final fileBytes = await getBytes(url);
    if (fileBytes != null) {
      return ZipDecoder().decodeBytes(fileBytes);
    } else {
      throw Exception('Failed to load file from $url');
    }
  }

  Future<Uint8List?> getBytes(String? url) async {
    if (url == null) {
      logger.err('Failed to load file from null link');
      return null;
    }
    return _fetchData<Uint8List>(
      url,
      (response) => response.bodyBytes,
    );
  }

  Future<T> _fetchData<T>(
    String url,
    T Function(http.Response response) parseResponse,
  ) async {
    final progress = logger.progress('Loading data from $url');

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          progress.complete('Data loaded successfully from $url');
          return parseResponse(response);
        } else if (_isServerError(response.statusCode) && attempt < _maxRetries) {
          logger.detail('Retry ${attempt + 1}/$_maxRetries for $url (status ${response.statusCode})');
          await Future<void>.delayed(Duration(milliseconds: _retryDelaysMs[attempt]));
          continue;
        } else {
          final errorMessage = 'Failed to load data from $url: ${response.statusCode} ${response.reasonPhrase}';
          progress.fail(errorMessage);
          throw Exception(errorMessage);
        }
      } on http.ClientException catch (e) {
        if (attempt < _maxRetries) {
          logger.detail('Retry ${attempt + 1}/$_maxRetries for $url ($e)');
          await Future<void>.delayed(Duration(milliseconds: _retryDelaysMs[attempt]));
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

  static bool _isServerError(int statusCode) => statusCode >= 500;
}
