import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';

const _gitUserName = commonName;
const _gitUserEmail = 'support@webtrit.com';

class GitRunner {
  const GitRunner({required this.logger});

  final Logger logger;

  ProcessResult runAdd({required String workingDirectoryPath}) {
    logger.info('Git adding keystore and associated metadata files from directory: $workingDirectoryPath');
    final result = Process.runSync(
      'git',
      ['add', '.'],
      workingDirectory: workingDirectoryPath,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      logger
        ..info(result.stdout.toString())
        ..err(result.stderr.toString());
    }

    return result;
  }

  ProcessResult runCommit({
    required String workingDirectoryPath,
    required String bundleId,
  }) {
    logger.info('Git committing keystore and associated metadata files');
    final result = Process.runSync(
      'git',
      [
        'commit',
        '-m',
        _commitMessage(bundleId),
        '--author',
        '$_gitUserName <$_gitUserEmail>',
      ],
      workingDirectory: workingDirectoryPath,
      environment: {
        'GIT_COMMITTER_NAME': _gitUserName,
        'GIT_COMMITTER_EMAIL': _gitUserEmail,
      },
      runInShell: true,
    );

    if (result.exitCode != 0) {
      logger
        ..info(result.stdout.toString())
        ..err(result.stderr.toString());
    }

    return result;
  }

  ProcessResult runPush({required String workingDirectoryPath}) {
    logger.info('Git pushing keystore and associated metadata files');
    final result = Process.runSync(
      'git',
      ['push'],
      workingDirectory: workingDirectoryPath,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      logger
        ..info(result.stdout.toString())
        ..err(result.stderr.toString());
    }

    return result;
  }

  static String _commitMessage(String bundleId) {
    return 'Add generated keystore with metadata for $bundleId';
  }
}
