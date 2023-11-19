import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/constants.dart';

const _bundleIdOptionName = 'bundleId';
const _appendDirectoryFlagName = 'appendDirectory';
const _executePushFlagName = 'executePush';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

const _gitUserName = commonName;
const _gitUserEmail = 'support@webtrit.com';

class KeystoreCommitCommand extends Command<int> {
  KeystoreCommitCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        _bundleIdOptionName,
        help: 'Android application bundle ID (aka applicationId).',
        mandatory: true,
      )
      ..addFlag(
        _appendDirectoryFlagName,
        help: 'Append the $_directoryParameterName with the "$_bundleIdOptionName".',
        negatable: false,
      )
      ..addFlag(
        _executePushFlagName,
        help: 'Execute push after commit.',
        negatable: false,
      );
  }

  @override
  String get name => 'keystore-commit';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Commit the newly generated keystore and associated metadata files for signing the WebTrit Phone Android application.',
      )
      ..write(parameterIndent)
      ..write(_directoryParameterDescriptionName)
      ..write(parameterDelimiter)
      ..writeln('Specify the directory for committing keystore and metadata files.')
      ..write(' ' * (parameterIndent.length + _directoryParameterDescriptionName.length + parameterDelimiter.length))
      ..write('Defaults to the current working directory if not provided.');
    return buffer.toString();
  }

  @override
  String get invocation => '${super.invocation} [$_directoryParameterName]';

  final Logger _logger;

  @override
  Future<int> run() async {
    final commandArgResults = argResults!;
    final bundleId = commandArgResults[_bundleIdOptionName] as String;
    if (bundleId.isEmpty) {
      _logger.err('Option "$_bundleIdOptionName" can not be empty.');
      return ExitCode.usage.code;
    }
    final appendDirectory = commandArgResults[_appendDirectoryFlagName] as bool;
    final executePush = commandArgResults[_executePushFlagName] as bool;

    String workingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      _logger.err('Only one "$_directoryParameterName" parameter can be passed.');
      return ExitCode.usage.code;
    }
    if (appendDirectory) {
      workingDirectoryPath = path.join(workingDirectoryPath, bundleId);
    }

    if (!Directory(workingDirectoryPath).existsSync()) {
      _logger.err('Directory does not exist: $workingDirectoryPath');
      return ExitCode.data.code;
    }

    _logger.info('Git adding keystore and associated metadata files from directory: $workingDirectoryPath');
    final gitAddProcess = Process.runSync(
      'git',
      [
        'add',
        '.',
      ],
      workingDirectory: workingDirectoryPath,
      runInShell: true,
    );
    if (gitAddProcess.exitCode != 0) {
      _logger
        ..info(gitAddProcess.stdout.toString())
        ..err(gitAddProcess.stderr.toString());
      return ExitCode.software.code;
    }

    _logger.info('Git committing keystore and associated metadata files');
    final gitCommitProcess = Process.runSync(
      'git',
      [
        'commit',
        '-m',
        commitMessage(bundleId),
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
    if (gitCommitProcess.exitCode != 0) {
      _logger
        ..info(gitCommitProcess.stdout.toString())
        ..err(gitCommitProcess.stderr.toString());
      return ExitCode.software.code;
    }

    if (executePush) {
      _logger.info('Git pushing keystore and associated metadata files');
      final gitPushProcess = Process.runSync(
        'git',
        [
          'push',
        ],
        workingDirectory: workingDirectoryPath,
        runInShell: true,
      );
      if (gitPushProcess.exitCode != 0) {
        _logger
          ..info(gitPushProcess.stdout.toString())
          ..err(gitPushProcess.stderr.toString());
        return ExitCode.software.code;
      }
    }

    return ExitCode.success.code;
  }
}

String commitMessage(String bundleId) {
  return 'Add generated keystore with metadata for $bundleId';
}
