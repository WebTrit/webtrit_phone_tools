import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/commands/keystore_metadata.dart';

const _bundleIdOptionName = 'bundleId';
const _createParentDirectoriesFlagName = 'createParentDirectories';
const _appendDirectoryFlagName = 'appendDirectory';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

const _storeFileName = 'upload-keystore.jks';
const _keytoolLogFileName = 'keytool.log';
const _keystoreMetadataFileName = 'upload-keystore-metadata.json';

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
    final commandArgResults = argResults!;
    final bundleId = commandArgResults[_bundleIdOptionName] as String;
    if (bundleId.isEmpty) {
      _logger.err('Option "$_bundleIdOptionName" can not be empty.');
      return ExitCode.usage.code;
    }
    final createParentDirectories = commandArgResults[_createParentDirectoriesFlagName] as bool;
    final appendDirectory = commandArgResults[_appendDirectoryFlagName] as bool;

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

    _logger.info('Creating working directory: $workingDirectoryPath');
    Directory(workingDirectoryPath).createSync(recursive: createParentDirectories);

    _logger.info('Initializing conventional keystore metadata');
    final keystoreMetadata = KeystoreMetadata.conventional(bundleId, _storeFileName);

    _logger.info('Generating key pair using keytool to: ${keystoreMetadata.storeFile}');
    final process = Process.runSync(
      'keytool',
      [
        '-genkeypair',
        '-keyalg',
        'RSA',
        '-keysize',
        '2048',
        '-validity',
        '${365 * 50}',
        '-alias',
        keystoreMetadata.keyAlias,
        '-keypass',
        keystoreMetadata.keyPassword,
        '-keystore',
        keystoreMetadata.storeFile,
        '-storepass',
        keystoreMetadata.storePassword,
        '-dname',
        keystoreMetadata.dname,
        '-v',
      ],
      workingDirectory: workingDirectoryPath,
      runInShell: true,
    );
    if (process.exitCode != 0) {
      _logger
        ..info(process.stdout.toString())
        ..err(process.stderr.toString());
      return ExitCode.software.code;
    } else {
      _logger.info('Writing keytool execution log to: $_keytoolLogFileName');
      final keytoolLogPath = path.join(workingDirectoryPath, _keytoolLogFileName);
      File(keytoolLogPath).writeAsStringSync(process.stdout.toString(), flush: true);
      File(keytoolLogPath).writeAsStringSync(process.stderr.toString(), mode: FileMode.append, flush: true);
    }

    _logger.info('Writing conventional keystore metadata to: $_keystoreMetadataFileName');
    final keystoreMetadataPath = path.join(workingDirectoryPath, _keystoreMetadataFileName);
    final metadataJsonString = keystoreMetadata.toJsonString();
    File(keystoreMetadataPath).writeAsStringSync(metadataJsonString, flush: true);

    return ExitCode.success.code;
  }
}
