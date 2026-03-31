import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/commands/keystore_generate/keystore_generate.dart';

class KeystoreGenerateRunner {
  const KeystoreGenerateRunner({required this.logger});

  final Logger logger;

  Future<int?> run({
    required String keystoreProjectPath,
    required String bundleId,
  }) async {
    logger.info('Running keystore-generate sub-command');
    final commandRunner = CommandRunner<int>('tool', 'A tool to manage keystore')
      ..addCommand(KeystoreGenerateCommand(logger: logger));
    return commandRunner.run([
      'keystore-generate',
      '--bundleId',
      bundleId,
      keystoreProjectPath,
    ]);
  }
}
