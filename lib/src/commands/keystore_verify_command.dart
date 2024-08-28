import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/models/keystore_metadata.dart';

const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

const _keystoreMetadataFileName = 'upload-keystore-metadata.json';

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
    final commandArgResults = argResults!;

    String workingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      _logger.err('Only one "$_directoryParameterName" parameter can be passed.');
      return ExitCode.usage.code;
    }

    final metadataFilePath = path.join(workingDirectoryPath, _keystoreMetadataFileName);
    final keystoreMetadata = KeystoreMetadata.fromJson(File(metadataFilePath).readAsStringSync());

    final p12KeystoreFilePath = path.join(workingDirectoryPath, keystoreMetadata.storeFileP12);
    final jksKeystoreFilePath = path.join(workingDirectoryPath, keystoreMetadata.storeFileJKS);

    if (File(p12KeystoreFilePath).existsSync()) {
      try {
        final sha256Fingerprint = getSHA256(p12KeystoreFilePath, keystoreMetadata.storePassword);
        _logger.info('P12 $sha256Fingerprint');
      } on Exception catch (e) {
        _logger.err(e.toString());
      }
    } else {
      _logger.err('P12 keystore file not found: $p12KeystoreFilePath');
    }

    if (File(jksKeystoreFilePath).existsSync()) {
      try {
        final sha256Fingerprint = getSHA256(jksKeystoreFilePath, keystoreMetadata.storePassword);
        _logger.info('JKS $sha256Fingerprint');
      } on Exception catch (e) {
        _logger.err(e.toString());
      }
    } else {
      _logger.info('JKS keystore file found: $jksKeystoreFilePath');
    }

    return ExitCode.success.code;
  }

  String getSHA256(String keystorePath, String storePassword) {
    final process = Process.runSync(
      'keytool',
      ['-list', '-v', '-keystore', keystorePath, '-storepass', storePassword],
      runInShell: true,
    );

    if (process.exitCode != 0) {
      _logger
        ..info(process.stdout.toString())
        ..err(process.stderr.toString());
      throw Exception('An error occurred while opening keystore: $keystorePath');
    }

    final output = process.stdout.toString();
    final exp = RegExp(r'SHA256:\s*([0-9A-Fa-f:]+)');
    final match = exp.stringMatch(output);

    if (match == null) throw Exception('SHA256 fingerprint not found in keystore: $keystorePath');

    return match;
  }
}
