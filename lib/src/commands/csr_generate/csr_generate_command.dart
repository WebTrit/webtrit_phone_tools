import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/constants.dart';
import 'models/models.dart';
import 'processors/processors.dart';
import 'runners/runners.dart';

const _emailOptionName = 'email';
const _commonNameOptionName = 'commonName';
const _keySizeOptionName = 'keySize';
const _createParentDirectoriesFlagName = 'createParentDirectories';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

class CsrGenerateCommand extends Command<int> {
  CsrGenerateCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        _emailOptionName,
        help: 'Email address embedded in the certificate signing request subject.',
        mandatory: true,
      )
      ..addOption(
        _commonNameOptionName,
        help: 'Common Name (CN) embedded in the certificate signing request subject.',
        mandatory: true,
      )
      ..addOption(
        _keySizeOptionName,
        help: 'RSA private key size in bits.',
        defaultsTo: '$defaultKeySize',
      )
      ..addFlag(
        _createParentDirectoriesFlagName,
        help: 'Create parent directories as needed.',
        negatable: false,
      );
  }

  @override
  String get name => 'csr-generate';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Generate an RSA private key and a certificate signing request (CSR) compatible with the Apple Developer '
        'portal, mirroring the Keychain Access certificate assistant.',
      )
      ..write(parameterIndent)
      ..write(_directoryParameterDescriptionName)
      ..write(parameterDelimiter)
      ..writeln('Specify the directory for creating the key and CSR files.')
      ..write(' ' * (parameterIndent.length + _directoryParameterDescriptionName.length + parameterDelimiter.length))
      ..write('Defaults to the current working directory if not provided.');
    return buffer.toString();
  }

  @override
  String get invocation => '${super.invocation} [$_directoryParameterName]';

  final Logger _logger;

  @override
  Future<int> run() async {
    final CsrGenerateContext context;
    try {
      context = _buildContext();
    } on UsageException catch (e) {
      _logger.err(e.message);
      return ExitCode.usage.code;
    }

    try {
      final fileProcessor = CsrFileProcessor(logger: _logger)
        ..createWorkingDirectory(
          workingDirectoryPath: context.workingDirectoryPath,
          createParentDirectories: context.createParentDirectories,
        );

      final opensslRunner = OpensslRunner(logger: _logger);
      final result = opensslRunner.runGenerateCsr(
        workingDirectoryPath: context.workingDirectoryPath,
        context: context,
      );
      fileProcessor.writeOpensslLog(
        workingDirectoryPath: context.workingDirectoryPath,
        processResult: result,
      );
      if (result.exitCode != 0) {
        return ExitCode.software.code;
      }

      _logger.success('Certificate signing request created in: ${context.workingDirectoryPath}');
      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.software.code;
    }
  }

  CsrGenerateContext _buildContext() {
    final commandArgResults = argResults!;

    final email = commandArgResults[_emailOptionName] as String;
    if (email.isEmpty) {
      throw UsageException('Option "$_emailOptionName" can not be empty.', usage);
    }

    final commonName = commandArgResults[_commonNameOptionName] as String;
    if (commonName.isEmpty) {
      throw UsageException('Option "$_commonNameOptionName" can not be empty.', usage);
    }

    final keySizeValue = commandArgResults[_keySizeOptionName] as String;
    final keySize = int.tryParse(keySizeValue);
    if (keySize == null || keySize <= 0) {
      throw UsageException('Option "$_keySizeOptionName" must be a positive integer.', usage);
    }

    String workingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      throw UsageException('Only one "$_directoryParameterName" parameter can be passed.', usage);
    }

    return CsrGenerateContext(
      workingDirectoryPath: path.normalize(workingDirectoryPath),
      email: email,
      commonName: commonName,
      keySize: keySize,
      createParentDirectories: commandArgResults[_createParentDirectoriesFlagName] as bool,
    );
  }
}
