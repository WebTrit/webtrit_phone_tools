import 'package:mason_logger/mason_logger.dart';

import 'package:data/datasource/configurator_backend/configurator_bakcend.dart';
import 'package:data/dto/application/application.dart';

class ApplicationFetcher {
  const ApplicationFetcher({
    required this.datasource,
    required this.logger,
  });

  final ConfiguratorBackandDatasource datasource;
  final Logger logger;

  Future<ApplicationDTO> fetch({
    required String applicationId,
    required Map<String, String> authHeader,
  }) async {
    logger.info('Fetching application: $applicationId');
    return datasource.getApplication(
      applicationId: applicationId,
      headers: authHeader,
    );
  }
}
