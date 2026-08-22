import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/configurator/configurator.dart';

class ApplicationFetcher {
  const ApplicationFetcher({
    required this.client,
    required this.logger,
  });

  final ConfiguratorClient client;
  final Logger logger;

  Future<ApplicationInfo> fetch({required String applicationId}) async {
    logger.info('Fetching application: $applicationId');
    return client.getApplication(applicationId);
  }
}
