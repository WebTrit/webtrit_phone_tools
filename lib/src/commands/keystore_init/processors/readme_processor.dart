import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/utils/utils.dart';

class ReadmeProcessor {
  const ReadmeProcessor({
    required this.keystoreReadmeUpdater,
    required this.logger,
  });

  final KeystoreReadmeUpdater keystoreReadmeUpdater;
  final Logger logger;

  Future<void> updateReadme({
    required String workingDirectoryPath,
    required String applicationName,
    required String applicationId,
  }) async {
    logger.info('Updating README with application record');
    await keystoreReadmeUpdater.addApplicationRecord(
      workingDirectoryPath,
      applicationName,
      applicationId,
    );
  }
}
