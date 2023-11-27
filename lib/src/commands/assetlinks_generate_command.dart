import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/asset_links_metadata.dart';
import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/commands/keystore_metadata.dart';

const _bundleIdOptionName = 'bundleId';
const _appleTeamIDOptionName = 'appleTeamID';

const _outputDirectoryName = 'output';

const _skipAssetlinksMetadata = 'skipAssetlinksMetadata';
const _appendWellKnowDirectory = 'appendWellKnowDirectory';

const _createParentDirectoriesFlagName = 'createParentDirectories';
const _appendDirectoryFlagName = 'appendDirectory';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

const _assetlinksMetadata = 'assetlinks-metadata.json';
const _appleAppSiteAssociation = 'apple-app-site-association.json';
const _assetlinks = 'assetlinks.json';
const _wellKnownPackage = '.well-known';

const _storeFileName = 'upload-keystore.jks';
const _keystoreMetadataFileName = 'upload-keystore-metadata.json';

class AssetlinksGenerateCommand extends Command<int> {
  AssetlinksGenerateCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        _bundleIdOptionName,
        help: 'Platform bundle ID.',
        mandatory: true,
      )
      ..addOption(
        _appleTeamIDOptionName,
        help: 'Apple Team ID',
        mandatory: true,
      )
      ..addFlag(
        _skipAssetlinksMetadata,
        help: 'Skip generation assetlinks metadata.',
        negatable: false,
      )
      ..addOption(
        _outputDirectoryName,
        help: 'Output .well-known files',
        mandatory: true,
      )
      ..addFlag(
        _appendWellKnowDirectory,
        help: 'Append .well-known directory.',
        negatable: false,
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
  String get name => 'assetlinks-generate';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Generate a .well-known files for configuration applinks in the WebTrit Phone Android application.',
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
    final teamId = commandArgResults[_appleTeamIDOptionName] as String;
    final output = commandArgResults[_outputDirectoryName] as String;
    if (bundleId.isEmpty) {
      _logger.err('Option "$_bundleIdOptionName" can not be empty.');
      return ExitCode.usage.code;
    }

    if (teamId.isEmpty) {
      _logger.err('Option "$_appleTeamIDOptionName" can not be empty.');
      return ExitCode.usage.code;
    }

    if (output.isEmpty) {
      _logger.err('Option "$_outputDirectoryName" can not be empty.');
      return ExitCode.usage.code;
    }
    final createParentDirectories = commandArgResults[_createParentDirectoriesFlagName] as bool;
    final appendDirectory = commandArgResults[_appendDirectoryFlagName] as bool;
    final appendWellKnownDirectory = commandArgResults[_appendWellKnowDirectory] as bool;

    String assetlinksMetadataWorkingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      assetlinksMetadataWorkingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      assetlinksMetadataWorkingDirectoryPath = commandArgResults.rest[0];
    } else {
      _logger.err('Only one "$_directoryParameterName" parameter can be passed.');
      return ExitCode.usage.code;
    }
    if (appendDirectory) {
      assetlinksMetadataWorkingDirectoryPath = path.join(assetlinksMetadataWorkingDirectoryPath, bundleId);
    }

    _logger.info('Creating working directory: $assetlinksMetadataWorkingDirectoryPath');
    Directory(assetlinksMetadataWorkingDirectoryPath).createSync(recursive: createParentDirectories);

    var welKnownWorkingDirectoryPath = output;
    if (appendWellKnownDirectory) {
      welKnownWorkingDirectoryPath = path.join(welKnownWorkingDirectoryPath, _wellKnownPackage);
    }

    _logger.info('Creating working directory: $welKnownWorkingDirectoryPath');
    Directory(welKnownWorkingDirectoryPath).createSync(recursive: appendWellKnownDirectory);

    final keystoreDirectoryPath = path.join(assetlinksMetadataWorkingDirectoryPath, _storeFileName);
    final metadataDirectoryPath = path.join(assetlinksMetadataWorkingDirectoryPath, _keystoreMetadataFileName);

    final jsonContent = File(metadataDirectoryPath).readAsStringSync();
    final jsonMap = KeystoreMetadata.fromJson(jsonContent);

    final process = Process.runSync(
      'keytool',
      [
        '-list',
        '-v',
        '-keystore',
        keystoreDirectoryPath,
        '-storepass',
        jsonMap.storePassword,
      ],
      runInShell: true,
    );

    String? sha256Fingerprint;
    if (process.exitCode != 0) {
      _logger
        ..info(process.stdout.toString())
        ..err(process.stderr.toString());
      return ExitCode.software.code;
    } else {
      final output = process.stdout.toString();
      final exp = RegExp(r'SHA256:\s*([0-9A-Fa-f:]+)');
      final match = exp.firstMatch(output);

      if (match != null) {
        sha256Fingerprint = match.group(1);
      } else {
        _logger.err('An error occurred while receiving sha256');
        return ExitCode.software.code;
      }
    }

    _logger.info('Writing Assetlinks metadata to: $_assetlinksMetadata');
    final assetLinksMetadata = AssetlinksMetadata(teamId: teamId);
    final metadataAssetlinksPath = path.join(assetlinksMetadataWorkingDirectoryPath, _assetlinksMetadata);
    final metadataAssetlinksJsonString = assetLinksMetadata.toJsonString();
    File(metadataAssetlinksPath).writeAsStringSync(metadataAssetlinksJsonString, flush: true);

    _logger.info('Writing Apple app site association to: $_appleAppSiteAssociation');
    final appleAppSiteAssociation = AppleAppSiteAssociation(teamId: teamId, bundleId: bundleId);
    final appleAppSiteAssociationPath = path.join(welKnownWorkingDirectoryPath, _appleAppSiteAssociation);
    final appleAppSiteAssociationJsonString = appleAppSiteAssociation.toJsonString();
    File(appleAppSiteAssociationPath).writeAsStringSync(appleAppSiteAssociationJsonString, flush: true);

    _logger.info('Writing Google asset links to: $_assetlinks');
    final assetLinks = AssetLinks(packageName: bundleId, sha256CertFingerprints: [sha256Fingerprint!]);
    final assetlinksPath = path.join(welKnownWorkingDirectoryPath, _assetlinks);
    final assetlinksJsonString = assetLinks.toJsonString();
    File(assetlinksPath).writeAsStringSync(assetlinksJsonString, flush: true);

    return ExitCode.success.code;
  }
}

class AssetLinks {
  AssetLinks({
    required this.packageName,
    required this.sha256CertFingerprints,
  });

  final String packageName;
  final List<String> sha256CertFingerprints;

  Map<String, dynamic> toJson() {
    return {
      'relation': ['delegate_permission/common.handle_all_urls'],
      'target': {
        'package_name': packageName,
        'sha256_cert_fingerprints': sha256CertFingerprints,
      },
    };
  }

  String toJsonString() {
    return (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(toJson()))).toString();
  }
}

class AppleAppSiteAssociation {
  AppleAppSiteAssociation({
    required this.teamId,
    required this.bundleId,
  });

  final String teamId;
  final String bundleId;

  Map<String, dynamic> toJson() {
    return {
      'applinks': {
        'details': [
          {
            'appID': '$teamId.$bundleId',
            'paths': ['*'],
          }
        ],
      },
    };
  }

  String toJsonString() {
    return (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(toJson()))).toString();
  }
}
