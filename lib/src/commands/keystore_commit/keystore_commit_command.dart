import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/constants.dart';

import 'models/models.dart';
import 'runners/runners.dart';

const _bundleIdOptionName = 'bundleId';
const _appendDirectoryFlagName = 'appendDirectory';
const _executePushFlagName = 'executePush';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

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
    try {
      final context = _buildContext();

      var workingDirectoryPath = context.workingDirectoryPath;
      if (context.appendDirectory) {
        workingDirectoryPath = path.join(workingDirectoryPath, context.bundleId);
      }

      if (!Directory(workingDirectoryPath).existsSync()) {
        _logger.err('Directory does not exist: $workingDirectoryPath');
        return ExitCode.data.code;
      }

      final gitRunner = GitRunner(logger: _logger);

      final addResult = gitRunner.runAdd(workingDirectoryPath: workingDirectoryPath);
      if (addResult.exitCode != 0) {
        return ExitCode.software.code;
      }

      final commitResult = gitRunner.runCommit(
        workingDirectoryPath: workingDirectoryPath,
        bundleId: context.bundleId,
      );
      if (commitResult.exitCode != 0) {
        return ExitCode.software.code;
      }

      if (context.executePush) {
        final pushResult = gitRunner.runPush(workingDirectoryPath: workingDirectoryPath);
        if (pushResult.exitCode != 0) {
          return ExitCode.software.code;
        }
      }

      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.software.code;
    }
  }

  KeystoreCommitContext _buildContext() {
    final commandArgResults = argResults!;
    final bundleId = commandArgResults[_bundleIdOptionName] as String;
    if (bundleId.isEmpty) {
      throw UsageException('Option "$_bundleIdOptionName" can not be empty.', usage);
    }
    final appendDirectory = commandArgResults[_appendDirectoryFlagName] as bool;
    final executePush = commandArgResults[_executePushFlagName] as bool;

    String workingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      throw UsageException('Only one "$_directoryParameterName" parameter can be passed.', usage);
    }

    return KeystoreCommitContext(
      workingDirectoryPath: workingDirectoryPath,
      bundleId: bundleId,
      appendDirectory: appendDirectory,
      executePush: executePush,
    );
  }
}
