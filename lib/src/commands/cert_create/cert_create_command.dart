import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/app_store_connect/app_store_connect.dart';
import 'package:webtrit_phone_tools/src/commands/csr_generate/models/models.dart';
import 'package:webtrit_phone_tools/src/commands/keystore_generate/models/models.dart';
import 'package:webtrit_phone_tools/src/constants.dart';

import 'models/models.dart';
import 'processors/processors.dart';

const _csrOptionName = 'csr';
const _outputOptionName = 'output';
const _typeOptionName = 'type';
const _issuerIdOptionName = 'issuerId';
const _keyIdOptionName = 'keyId';
const _authKeyOptionName = 'authKey';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

class CertCreateCommand extends Command<int> {
  CertCreateCommand({
    required Logger logger,
    http.Client? httpClient,
  })  : _logger = logger,
        _httpClient = httpClient {
    argParser
      ..addOption(
        _csrOptionName,
        help: 'Certificate signing request to submit, as produced by csr-generate.',
        defaultsTo: certificateSigningRequestFileName,
      )
      ..addOption(
        _outputOptionName,
        help: 'Certificate file to write.',
        defaultsTo: distributionCertificateFileName,
      )
      ..addOption(
        _typeOptionName,
        help: 'Certificate type to request from App Store Connect.',
        defaultsTo: appleDistributionCertificateType,
      )
      ..addOption(
        _issuerIdOptionName,
        help: 'Issuer id of the App Store Connect key. Defaults to the one in the metadata.',
        defaultsTo: '',
      )
      ..addOption(
        _keyIdOptionName,
        help: 'Key id of the App Store Connect key. Defaults to the one in the metadata.',
        defaultsTo: '',
      )
      ..addOption(
        _authKeyOptionName,
        help: 'Private key file of the App Store Connect key. Defaults to AuthKey_<key id>.p8 in the directory.',
        defaultsTo: '',
      );
  }

  @override
  String get name => 'cert-create';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Submit a certificate signing request to App Store Connect and download the distribution certificate it '
        'issues, replacing the round trip through the Apple Developer portal.',
      )
      ..write(parameterIndent)
      ..write(_directoryParameterDescriptionName)
      ..write(parameterDelimiter)
      ..writeln('Directory holding the signing request, the App Store Connect key, and the metadata.')
      ..write(' ' * (parameterIndent.length + _directoryParameterDescriptionName.length + parameterDelimiter.length))
      ..write('Defaults to the current working directory if not provided.');
    return buffer.toString();
  }

  @override
  String get invocation => '${super.invocation} [$_directoryParameterName]';

  final Logger _logger;
  final http.Client? _httpClient;

  @override
  Future<int> run() async {
    final CertCreateContext context;
    try {
      context = _buildContext();
    } on UsageException catch (e) {
      _logger.err(e.message);
      return ExitCode.usage.code;
    }

    final metadata = SigningMetadataProcessor(logger: _logger).read(context.metadataPath);
    final credentials = SigningCredentialsProcessor(logger: _logger).resolve(
      directoryPath: context.workingDirectoryPath,
      metadata: metadata,
      issuerIdOverride: context.issuerId,
      keyIdOverride: context.keyId,
      authKeyPathOverride: context.authKeyPath,
    );
    if (credentials == null) {
      return ExitCode.usage.code;
    }

    final token = AppleJwtRunner(logger: _logger).issueToken(credentials: credentials);
    if (token == null) {
      return ExitCode.software.code;
    }

    final client = AppStoreConnectClient(token: token, logger: _logger, httpClient: _httpClient);
    final processor = CertificateProcessor(logger: _logger);
    final progress = _logger.progress('Requesting a ${context.certificateType} certificate');
    try {
      final certificate = await client.createCertificate(
        csrContent: processor.readCertificateSigningRequest(context.certificateSigningRequestPath),
        certificateType: context.certificateType,
      );
      progress.complete('Certificate ${certificate.id} issued');

      processor.writeCertificate(
        certificatePath: context.certificatePath,
        certificateContent: certificate.content,
      );

      _logger.success('Certificate written to: ${context.certificatePath}');
      return ExitCode.success.code;
    } on AppStoreConnectException catch (e) {
      progress.fail(e.toString());
      return ExitCode.software.code;
    } catch (e, s) {
      progress.fail('Execution failed: $e');
      _logger.detail('$s');
      return ExitCode.software.code;
    } finally {
      client.close();
    }
  }

  CertCreateContext _buildContext() {
    final commandArgResults = argResults!;

    final certificateType = commandArgResults[_typeOptionName] as String;
    if (certificateType.isEmpty) {
      throw UsageException('Option "$_typeOptionName" can not be empty.', usage);
    }

    String workingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      throw UsageException('Only one "$_directoryParameterName" parameter can be passed.', usage);
    }
    workingDirectoryPath = path.normalize(workingDirectoryPath);

    final certificateSigningRequestPath =
        _resolvePath(workingDirectoryPath, commandArgResults[_csrOptionName] as String);
    if (!File(certificateSigningRequestPath).existsSync()) {
      throw UsageException('Certificate signing request not found: $certificateSigningRequestPath', usage);
    }

    final authKey = commandArgResults[_authKeyOptionName] as String;

    return CertCreateContext(
      workingDirectoryPath: workingDirectoryPath,
      certificateSigningRequestPath: certificateSigningRequestPath,
      certificatePath: _resolvePath(workingDirectoryPath, commandArgResults[_outputOptionName] as String),
      metadataPath: path.join(workingDirectoryPath, iosCredentials),
      certificateType: certificateType,
      issuerId: commandArgResults[_issuerIdOptionName] as String,
      keyId: commandArgResults[_keyIdOptionName] as String,
      authKeyPath: authKey.isEmpty ? '' : _resolvePath(workingDirectoryPath, authKey),
    );
  }

  String _resolvePath(String workingDirectoryPath, String target) =>
      path.isAbsolute(target) ? target : path.join(workingDirectoryPath, target);
}
