import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/constants.dart';

import 'models/models.dart';
import 'processors/processors.dart';
import 'runners/runners.dart';

const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

class KeystoreVerifyCommand extends Command<int> {
  KeystoreVerifyCommand({
    required Logger logger,
  }) : _logger = logger;

  @override
  String get name => 'keystore-verify';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Verify the keystore and associated metadata files for signing the WebTrit Phone Android application.',
      )
      ..write(parameterIndent)
      ..write(_directoryParameterDescriptionName)
      ..write(parameterDelimiter)
      ..writeln('Specify the directory for keystore and metadata files.')
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

      final metadataReader = KeystoreMetadataReader(logger: _logger);
      final keystoreMetadata = metadataReader.read(
        workingDirectoryPath: context.workingDirectoryPath,
      );

      final keytoolRunner = KeytoolRunner(logger: _logger);

      final p12KeystoreFilePath = path.join(context.workingDirectoryPath, keystoreMetadata.storeFileP12);
      final jksKeystoreFilePath = path.join(context.workingDirectoryPath, keystoreMetadata.storeFileJKS);

      if (File(p12KeystoreFilePath).existsSync()) {
        try {
          final sha256Fingerprint = keytoolRunner.getSHA256(
            keystorePath: p12KeystoreFilePath,
            storePassword: keystoreMetadata.storePassword,
          );
          _logger.info('P12 $sha256Fingerprint');
        } on Exception catch (e) {
          _logger.err(e.toString());
        }
      } else {
        _logger.err('P12 keystore file not found: $p12KeystoreFilePath');
      }

      if (File(jksKeystoreFilePath).existsSync()) {
        try {
          final sha256Fingerprint = keytoolRunner.getSHA256(
            keystorePath: jksKeystoreFilePath,
            storePassword: keystoreMetadata.storePassword,
          );
          _logger.info('JKS $sha256Fingerprint');
        } on Exception catch (e) {
          _logger.err(e.toString());
        }
      } else {
        _logger.info('JKS keystore file found: $jksKeystoreFilePath');
      }

      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.software.code;
    }
  }

  KeystoreVerifyContext _buildContext() {
    final commandArgResults = argResults!;

    String workingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      throw UsageException('Only one "$_directoryParameterName" parameter can be passed.', usage);
    }

    return KeystoreVerifyContext(
      workingDirectoryPath: workingDirectoryPath,
    );
  }
}
