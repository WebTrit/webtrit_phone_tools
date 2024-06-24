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
    final progress = logger.progress('Loading data from $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        progress.complete('Data loaded successfully from $url');
        return ApplicationDTO.fromJsonString(response.body);
      } else {
        progress.fail('Failed to load data from $url: ${response.statusCode}');
        throw Exception('Failed to load data from $url: ${response.statusCode}');
      }
    } catch (e) {
      progress.fail('Failed to load data from $url: $e');
      rethrow;
    }
  }

  Future<ThemeDTO> getTheme(String applicationId, String themeId) async {
    final url = _themeUrl(applicationId, themeId);
    final progress = logger.progress('Loading data from $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        progress.complete('Data loaded successfully from $url');
        return ThemeDTO.fromJsonString(response.body);
      } else {
        progress.fail('Failed to load data from $url: ${response.statusCode}');
        throw Exception('Failed to load data from $url: ${response.statusCode}');
      }
    } catch (e) {
      progress.fail('Failed to load data from $url: $e');
      rethrow;
    }
  }

  Future<Archive> getTranslationFiles(String applicationId) async {
    final url = _translationsUrl(applicationId);
    final progress = logger.progress('Loading file from $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        progress.complete('File loaded successfully from $url');
        return ZipDecoder().decodeBytes(response.bodyBytes);
      } else {
        progress.fail('Failed to load file from $url: ${response.statusCode}');
        throw Exception('Failed to load file from $url: ${response.statusCode}');
      }
    } catch (e) {
      progress.fail('Failed to load file from $url: $e');
      rethrow;
    }
  }
}
