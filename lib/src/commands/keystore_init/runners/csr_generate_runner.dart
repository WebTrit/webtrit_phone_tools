import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/commands/csr_generate/csr_generate.dart';

const _appleDeveloperAccountEmail = 'app.admin@webtrit.com';

class CsrGenerateRunner {
  const CsrGenerateRunner({required this.logger});

  final Logger logger;

  Future<int?> run({
    required String keystoreProjectPath,
    required String applicationName,
  }) async {
    logger.info('Running csr-generate sub-command');
    final commandRunner = CommandRunner<int>('tool', 'A tool to manage keystore')
      ..addCommand(CsrGenerateCommand(logger: logger));
    return commandRunner.run([
      'csr-generate',
      '--email',
      _appleDeveloperAccountEmail,
      '--commonName',
      '$applicationName admin certificate request',
      keystoreProjectPath,
    ]);
  }
}
