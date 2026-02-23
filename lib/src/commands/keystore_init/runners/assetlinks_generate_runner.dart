import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/assetlinks_generate/assetlinks_generate.dart';

class AssetlinksGenerateRunner {
  const AssetlinksGenerateRunner({required this.logger});

  final Logger logger;

  Future<int?> run({
    required String keystoreProjectPath,
    required String iosPlatformId,
    required String uploadFingerprint,
  }) async {
    logger.info('Running assetlinks-generate sub-command');
    final commandRunner = CommandRunner<int>('tool', 'A tool to manage keystore')
      ..addCommand(AssetlinksGenerateCommand(logger: logger));
    return commandRunner.run([
      'assetlinks-generate',
      '--bundleId',
      iosPlatformId,
      '--androidFingerprints',
      uploadFingerprint,
      '--appleTeamID',
      'test',
      '--output',
      path.join(keystoreProjectPath, 'deep_links'),
      '--appendWellKnowDirectory',
      keystoreProjectPath,
    ]);
  }
}
