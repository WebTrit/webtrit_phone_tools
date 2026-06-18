import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/csr_generate/models/models.dart';
import 'package:webtrit_phone_tools/src/commands/keystore_generate/models/models.dart';
import 'package:webtrit_phone_tools/src/constants.dart';

import 'models/models.dart';
import 'processors/processors.dart';
import 'runners/runners.dart';

const _certOptionName = 'cert';
const _keyOptionName = 'key';
const _outputOptionName = 'output';
const _passwordOptionName = 'password';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

class CsrFinalizeCommand extends Command<int> {
  CsrFinalizeCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        _certOptionName,
        help: 'Path to the certificate (.cer) downloaded from the Apple Developer portal.',
        mandatory: true,
      )
      ..addOption(
        _keyOptionName,
        help: 'Private key file generated alongside the certificate signing request.',
        defaultsTo: privateKeyFileName,
      )
      ..addOption(
        _outputOptionName,
        help: 'PKCS12 bundle file to create.',
        defaultsTo: iosCertificates,
      )
      ..addOption(
        _passwordOptionName,
        help: 'Export password for the PKCS12 bundle.',
        defaultsTo: '',
      );
  }

  @override
  String get name => 'csr-finalize';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Bundle a downloaded Apple certificate with its private key into a PKCS12 file, compute the code signing '
        'identity, and write it to the App Store Connect metadata.',
      )
      ..write(parameterIndent)
      ..write(_directoryParameterDescriptionName)
      ..write(parameterDelimiter)
      ..writeln('Directory holding the private key, metadata, and output bundle.')
      ..write(' ' * (parameterIndent.length + _directoryParameterDescriptionName.length + parameterDelimiter.length))
      ..write('Defaults to the current working directory if not provided.');
    return buffer.toString();
  }

  @override
  String get invocation => '${super.invocation} [$_directoryParameterName]';

  final Logger _logger;

  @override
  Future<int> run() async {
    final CsrFinalizeContext context;
    try {
      context = _buildContext();
    } on UsageException catch (e) {
      _logger.err(e.message);
      return ExitCode.usage.code;
    }

    final tempDirectory = Directory.systemTemp.createTempSync('csr_finalize');
    final pemPath = path.join(tempDirectory.path, 'certificate.pem');
    try {
      final opensslRunner = OpensslRunner(logger: _logger);

      if (!opensslRunner.convertCertificateToPem(certificatePath: context.certificatePath, pemPath: pemPath)) {
        return ExitCode.software.code;
      }

      final pkcs12Result = opensslRunner.buildPkcs12(
        pemPath: pemPath,
        privateKeyPath: context.privateKeyPath,
        pkcs12Path: context.pkcs12Path,
        password: context.password,
      );
      if (pkcs12Result.exitCode != 0) {
        return ExitCode.software.code;
      }

      final identity = opensslRunner.extractCodeSigningIdentity(pemPath: pemPath);
      if (identity == null) {
        return ExitCode.software.code;
      }

      MetadataProcessor(logger: _logger).writeCodeSigningIdentity(
        metadataPath: context.metadataPath,
        identity: identity,
      );

      _logger
        ..success('PKCS12 bundle created: ${context.pkcs12Path}')
        ..success('Code signing identity: $identity');
      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.software.code;
    } finally {
      tempDirectory.deleteSync(recursive: true);
    }
  }

  CsrFinalizeContext _buildContext() {
    final commandArgResults = argResults!;

    final certificate = commandArgResults[_certOptionName] as String;
    if (certificate.isEmpty) {
      throw UsageException('Option "$_certOptionName" can not be empty.', usage);
    }

    String workingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      throw UsageException('Only one "$_directoryParameterName" parameter can be passed.', usage);
    }

    final certificatePath = _resolvePath(workingDirectoryPath, certificate);
    final privateKeyPath = _resolvePath(workingDirectoryPath, commandArgResults[_keyOptionName] as String);
    final pkcs12Path = _resolvePath(workingDirectoryPath, commandArgResults[_outputOptionName] as String);
    final metadataPath = path.join(workingDirectoryPath, iosCredentials);

    if (!File(certificatePath).existsSync()) {
      throw UsageException('Certificate not found: $certificatePath', usage);
    }
    if (!File(privateKeyPath).existsSync()) {
      throw UsageException('Private key not found: $privateKeyPath', usage);
    }

    return CsrFinalizeContext(
      certificatePath: certificatePath,
      privateKeyPath: privateKeyPath,
      pkcs12Path: pkcs12Path,
      metadataPath: metadataPath,
      password: commandArgResults[_passwordOptionName] as String,
    );
  }

  String _resolvePath(String workingDirectoryPath, String target) =>
      path.isAbsolute(target) ? target : path.join(workingDirectoryPath, target);
}
