import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/models/keystore_metadata.dart';

import 'models/models.dart';
import 'processors/processors.dart';
import 'runners/runners.dart';

const _bundleIdOptionName = 'bundleId';
const _createParentDirectoriesFlagName = 'createParentDirectories';
const _appendDirectoryFlagName = 'appendDirectory';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

class KeystoreGenerateCommand extends Command<int> {
  KeystoreGenerateCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        _bundleIdOptionName,
        help: 'Android application bundle ID (aka applicationId).',
        mandatory: true,
      )
      ..addFlag(
        _createParentDirectoriesFlagName,
        help: 'Create parent directories as needed.',
        negatable: false,
      )
      ..addFlag(
        _appendDirectoryFlagName,
        help: 'Append the $_directoryParameterName with the "$_bundleIdOptionName".',
        negatable: false,
      );
  }

  @override
  String get name => 'keystore-generate';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Generate a keystore and associated metadata files for signing the WebTrit Phone Android application.',
      )
      ..write(parameterIndent)
      ..write(_directoryParameterDescriptionName)
      ..write(parameterDelimiter)
      ..writeln('Specify the directory for creating keystore and metadata files.')
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

      final workingDirectoryPath = context.appendDirectory
          ? path.join(context.workingDirectoryPath, context.bundleId)
          : context.workingDirectoryPath;

      final fileProcessor = KeystoreFileProcessor(logger: _logger)
        ..createWorkingDirectory(
          workingDirectoryPath: workingDirectoryPath,
          createParentDirectories: context.createParentDirectories,
        );

      _logger.info('Initializing conventional keystore metadata');
      final keystoreMetadata = KeystoreMetadata.conventional(context.bundleId);

      final keytoolRunner = KeytoolRunner(logger: _logger);

      final genkeypairResult = keytoolRunner.runGenkeypair(
        workingDirectoryPath: workingDirectoryPath,
        metadata: keystoreMetadata,
      );
      if (genkeypairResult.exitCode != 0) {
        return ExitCode.software.code;
      }
      fileProcessor.writeKeytoolLog(
        workingDirectoryPath: workingDirectoryPath,
        processResult: genkeypairResult,
      );

      final importResult = keytoolRunner.runImportKeystore(
        workingDirectoryPath: workingDirectoryPath,
        metadata: keystoreMetadata,
      );
      if (importResult.exitCode != 0) {
        return ExitCode.software.code;
      }
      fileProcessor
        ..writeKeytoolLog(
          workingDirectoryPath: workingDirectoryPath,
          processResult: importResult,
        )
        ..writeMetadata(
          workingDirectoryPath: workingDirectoryPath,
          metadata: keystoreMetadata,
        );

      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.software.code;
    }
  }

  KeystoreGenerateContext _buildContext() {
    final commandArgResults = argResults!;
    final bundleId = commandArgResults[_bundleIdOptionName] as String;
    if (bundleId.isEmpty) {
      throw UsageException('Option "$_bundleIdOptionName" can not be empty.', usage);
    }
    final createParentDirectories = commandArgResults[_createParentDirectoriesFlagName] as bool;
    final appendDirectory = commandArgResults[_appendDirectoryFlagName] as bool;

    String workingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      throw UsageException('Only one "$_directoryParameterName" parameter can be passed.', usage);
    }

    return KeystoreGenerateContext(
      workingDirectoryPath: workingDirectoryPath,
      bundleId: bundleId,
      createParentDirectories: createParentDirectories,
      appendDirectory: appendDirectory,
    );
  }
}
