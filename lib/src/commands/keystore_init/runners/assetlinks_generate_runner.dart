import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/assetlinks_generate/assetlinks_generate.dart';

/// Stands in for a real Apple team, which nothing in this tool knows. The file
/// it produces cannot verify a deep link until a real one is supplied - see the
/// note in the keystore-init command.
const placeholderAppleTeamId = 'test';

class AssetlinksGenerateRunner {
  const AssetlinksGenerateRunner({required this.logger});

  final Logger logger;

  Future<int?> run({
    required String keystoreProjectPath,
    required String uploadFingerprint,
    String? iosPlatformId,
    String? androidPlatformId,
  }) async {
    logger.info('Running assetlinks-generate sub-command');
    final commandRunner = CommandRunner<int>('tool', 'A tool to manage keystore')
      ..addCommand(AssetlinksGenerateCommand(logger: logger));
    return commandRunner.run([
      'assetlinks-generate',
      '--bundleId',
      iosPlatformId ?? '',
      // Android verifies the package that signed the app, which is not always
      // what Apple verifies: two brands in production carry different
      // identifiers, and until now the Android file was handed the Apple one.
      '--androidBundleId',
      androidPlatformId ?? '',
      '--androidFingerprints',
      uploadFingerprint,
      '--appleTeamID',
      placeholderAppleTeamId,
      '--output',
      path.join(keystoreProjectPath, 'deep_links'),
      '--appendWellKnowDirectory',
      keystoreProjectPath,
    ]);
  }
}
