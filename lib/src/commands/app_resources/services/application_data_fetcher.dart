import 'package:mason_logger/mason_logger.dart';

import 'package:data/datasource/datasource.dart';
import 'package:data/dto/dto.dart';

class ApplicationDataFetcher {
  const ApplicationDataFetcher({
    required this.datasource,
    required this.logger,
  });

  final ConfiguratorBackandDatasource datasource;
  final Logger logger;

  Future<(ApplicationDTO, ThemeDTO)> fetch({
    required String applicationId,
    required Map<String, String> authHeader,
  }) async {
    final application = await datasource.getApplication(
      applicationId: applicationId,
      headers: authHeader,
    );

    if (application.theme == null) {
      throw Exception('Application $applicationId does not have a default theme.');
    }

    final theme = await datasource.getTheme(
      applicationId: applicationId,
      themeId: application.theme!,
      headers: authHeader,
    );

    logger.info('- Fetched theme: ${theme.id}');
    return (application, theme);
  }
}
