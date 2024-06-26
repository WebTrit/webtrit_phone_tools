import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:archive/archive.dart';

import 'package:dto/dto.dart';

class HttpClient {
  HttpClient(this.baseUrl, this.logger);

  final String baseUrl;
  final Logger logger;

  String _applicationUrl(String applicationId) {
    return '$baseUrl/api/v1/applications/$applicationId';
  }

  String _themeUrl(String applicationId, String themeId) {
    return '$baseUrl/api/v1/applications/$applicationId/themes/$themeId';
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

  Future<ThemeDTO> getTheme(String applicationId, String themeId) async {
    final url = _themeUrl(applicationId, themeId);
    return _fetchData<ThemeDTO>(
      url,
      (response) => ThemeDTO.fromJsonString(response.body),
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

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        progress.complete('Data loaded successfully from $url');
        return parseResponse(response);
      } else {
        final errorMessage = 'Failed to load data from $url: ${response.statusCode} ${response.reasonPhrase}';
        progress.fail(errorMessage);
        throw Exception(errorMessage);
      }
    } catch (e) {
      final errorMessage = 'Failed to load data from $url: $e';
      progress.fail(errorMessage);
      throw Exception(errorMessage);
    }
  }
}
