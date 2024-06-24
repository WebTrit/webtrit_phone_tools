import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';

class DatasourceProvider {
  DatasourceProvider(this.logger);

  final Logger logger;

  Future<T> getHttpData<T>(String url, T Function(String) fromBody) async {
    final progress = logger.progress('Loading data from $url');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        progress.complete('Data loaded successfully from $url');
        return fromBody(response.body);
      } else {
        progress.fail('Failed to load data from $url: ${response.statusCode}');
        throw Exception('Failed to load data from $url: ${response.statusCode}');
      }
    } catch (e) {
      progress.fail('Failed to load data from $url: $e');
      rethrow;
    }
  }
}
