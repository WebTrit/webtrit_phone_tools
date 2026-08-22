import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/configurator/configurator.dart';

class ApplicationDataFetcher {
  const ApplicationDataFetcher({
    required this.client,
    required this.logger,
  });

  final ConfiguratorClient client;
  final Logger logger;

  Future<(ApplicationInfo, ThemeInfo)> fetch({
    required String applicationId,
  }) async {
    final application = await client.getApplication(applicationId);

    if (application.theme == null) {
      throw Exception('Application $applicationId does not have a default theme.');
    }

    final theme = await client.getTheme(applicationId, application.theme!);

    logger.info('- Fetched theme: ${theme.id}');
    return (application, theme);
  }
}
