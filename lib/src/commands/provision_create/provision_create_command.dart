import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/app_store_connect/app_store_connect.dart';
import 'package:webtrit_phone_tools/src/commands/cert_create/models/models.dart';
import 'package:webtrit_phone_tools/src/commands/keystore_generate/models/models.dart';
import 'package:webtrit_phone_tools/src/constants.dart';

import 'models/models.dart';
import 'processors/processors.dart';

const _certOptionName = 'cert';
const _outputOptionName = 'output';
const _nameOptionName = 'name';
const _typeOptionName = 'type';
const _bundleIdOptionName = 'bundleId';
const _issuerIdOptionName = 'issuerId';
const _keyIdOptionName = 'keyId';
const _authKeyOptionName = 'authKey';
const _replaceExistingFlagName = 'replaceExisting';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

class ProvisionCreateCommand extends Command<int> {
  ProvisionCreateCommand({
    required Logger logger,
    http.Client? httpClient,
  })  : _logger = logger,
        _httpClient = httpClient {
    argParser
      ..addOption(
        _certOptionName,
        help: 'Certificate the profile is issued against, as downloaded by cert-create.',
        defaultsTo: distributionCertificateFileName,
      )
      ..addOption(
        _outputOptionName,
        help: 'Provisioning profile file to write.',
        defaultsTo: iosProvision,
      )
      ..addOption(
        _nameOptionName,
        help: 'Name the profile carries on the Apple Developer portal.',
        defaultsTo: defaultProfileName,
      )
      ..addOption(
        _typeOptionName,
        help: 'Profile type to create.',
        defaultsTo: appStoreProfileType,
      )
      ..addOption(
        _bundleIdOptionName,
        help: 'Bundle id the profile is issued for. Defaults to the one in the metadata.',
        defaultsTo: '',
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
      )
      ..addFlag(
        _replaceExistingFlagName,
        help: 'Delete a profile that already holds the name but covers something else, then create it anew.',
        negatable: false,
      );
  }

  @override
  String get name => 'provision-create';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Create the App Store provisioning profile for a bundle id through App Store Connect, download it, and write '
        'the team id it carries to the metadata.',
      )
      ..write(parameterIndent)
      ..write(_directoryParameterDescriptionName)
      ..write(parameterDelimiter)
      ..writeln('Directory holding the certificate, the App Store Connect key, and the metadata.')
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
    final ProvisionCreateContext context;
    try {
      context = _buildContext();
    } on UsageException catch (e) {
      _logger.err(e.message);
      return ExitCode.usage.code;
    }

    final metadataProcessor = SigningMetadataProcessor(logger: _logger);
    final metadata = metadataProcessor.read(context.metadataPath);

    final bundleId = context.bundleId.isNotEmpty ? context.bundleId : metadata[bundleIdMetadataKey] as String? ?? '';
    if (bundleId.isEmpty) {
      _logger.err('No "$bundleIdMetadataKey" in the metadata: fill it in or pass it as an option.');
      return ExitCode.usage.code;
    }

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
    final processor = ProfileProcessor(logger: _logger);
    final progress = _logger.progress('Resolving the profile for $bundleId');
    try {
      final certificateId = await _resolveCertificateId(client, processor.readCertificateContent(context.certificatePath));
      if (certificateId == null) {
        progress.fail("The certificate in ${context.certificatePath} is not one of the account's certificates.");
        return ExitCode.software.code;
      }

      final bundleIdResourceId = await client.bundleIdResourceId(bundleId);
      if (bundleIdResourceId == null) {
        progress.fail('No identifier registered for $bundleId on the Apple Developer portal.');
        return ExitCode.software.code;
      }

      final profile = await _resolveProfile(
        client: client,
        context: context,
        bundleIdResourceId: bundleIdResourceId,
        certificateId: certificateId,
      );
      progress.complete('Profile ${profile.name} (${profile.id}) ready');

      processor.writeProfile(profilePath: context.profilePath, profileContent: profile.content);

      final teamId = processor.extractTeamId(context.profilePath);
      if (teamId == null) {
        return ExitCode.software.code;
      }

      metadataProcessor.write(metadataPath: context.metadataPath, key: teamIdMetadataKey, value: teamId);

      _logger
        ..success('Provisioning profile written to: ${context.profilePath}')
        ..success('Team id: $teamId');
      return ExitCode.success.code;
    } on ProvisionConflictException catch (e) {
      progress.fail(e.message);
      return ExitCode.usage.code;
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

  Future<String?> _resolveCertificateId(AppStoreConnectClient client, String certificateContent) async {
    for (final certificate in await client.certificates()) {
      if (certificate.content == certificateContent) {
        return certificate.id;
      }
    }
    return null;
  }

  Future<AppStoreProfile> _resolveProfile({
    required AppStoreConnectClient client,
    required ProvisionCreateContext context,
    required String bundleIdResourceId,
    required String certificateId,
  }) async {
    // `filter[name]` matches by prefix, so the name is compared again here.
    final named = (await client.profiles(name: context.profileName))
        .where((profile) => profile.name == context.profileName)
        .toList(growable: false);

    for (final profile in named) {
      final covers = profile.state == activeProfileState &&
          profile.bundleIdResourceId == bundleIdResourceId &&
          profile.certificateIds.contains(certificateId);
      if (covers) {
        _logger.detail('Reusing profile ${profile.id}');
        return profile;
      }
    }

    if (named.isNotEmpty) {
      if (!context.replaceExisting) {
        throw ProvisionConflictException(
          'A profile named "${context.profileName}" already exists and covers something else. Pass '
          '--$_replaceExistingFlagName to replace it, or --$_nameOptionName to use another name.',
        );
      }
      for (final profile in named) {
        _logger.info('Deleting profile ${profile.id} to free the name "${context.profileName}"');
        await client.deleteProfile(profile.id);
      }
    }

    return client.createProfile(
      name: context.profileName,
      bundleIdResourceId: bundleIdResourceId,
      certificateIds: [certificateId],
      profileType: context.profileType,
    );
  }

  ProvisionCreateContext _buildContext() {
    final commandArgResults = argResults!;

    final profileName = commandArgResults[_nameOptionName] as String;
    if (profileName.isEmpty) {
      throw UsageException('Option "$_nameOptionName" can not be empty.', usage);
    }

    final profileType = commandArgResults[_typeOptionName] as String;
    if (profileType.isEmpty) {
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

    final certificatePath = _resolvePath(workingDirectoryPath, commandArgResults[_certOptionName] as String);
    if (!File(certificatePath).existsSync()) {
      throw UsageException('Certificate not found: $certificatePath', usage);
    }

    final authKey = commandArgResults[_authKeyOptionName] as String;

    return ProvisionCreateContext(
      workingDirectoryPath: workingDirectoryPath,
      certificatePath: certificatePath,
      profilePath: _resolvePath(workingDirectoryPath, commandArgResults[_outputOptionName] as String),
      metadataPath: path.join(workingDirectoryPath, iosCredentials),
      profileName: profileName,
      profileType: profileType,
      bundleId: commandArgResults[_bundleIdOptionName] as String,
      replaceExisting: commandArgResults[_replaceExistingFlagName] as bool,
      issuerId: commandArgResults[_issuerIdOptionName] as String,
      keyId: commandArgResults[_keyIdOptionName] as String,
      authKeyPath: authKey.isEmpty ? '' : _resolvePath(workingDirectoryPath, authKey),
    );
  }

  String _resolvePath(String workingDirectoryPath, String target) =>
      path.isAbsolute(target) ? target : path.join(workingDirectoryPath, target);
}
