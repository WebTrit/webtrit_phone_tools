import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:simple_mustache/simple_mustache.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/extension/mustache_extension.dart';

import '../gen/assets.dart';

const _bundleIdOptionName = 'bundleId';
const _appleTeamIDOptionName = 'appleTeamID';
const _androidFingerprint = 'androidFingerprint';

const _outputDirectoryName = 'output';

const _appendWellKnowDirectory = 'appendWellKnowDirectory';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

const _appleAppSiteAssociation = 'apple-app-site-association.json';
const _assetlinks = 'assetlinks.json';
const _wellKnownPackage = '.well-known';

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
      ..addMultiOption(
        _androidFingerprint,
        help: 'Android Fingerprints (comma-separated)',
        defaultsTo: [],
      )
      ..addOption(
        _outputDirectoryName,
        help: 'Output .well-known files',
        mandatory: true,
      )
      ..addOption(
        _appleTeamIDOptionName,
        help: 'Apple Team ID',
      )
      ..addFlag(
        _appendWellKnowDirectory,
        help: 'Append .well-known directory.',
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
    final androidFingerprints = commandArgResults[_androidFingerprint] as List<String>;
    final outputPath = commandArgResults[_outputDirectoryName] as String;

    final teamIdArg = commandArgResults[_appleTeamIDOptionName] as String?;

    final appendWellKnownDirectory = commandArgResults[_appendWellKnowDirectory] as bool;

    if (bundleId.isEmpty) {
      _logger.err('Option "$_bundleIdOptionName" can not be empty.');
      return ExitCode.usage.code;
    }

    if (androidFingerprints.isEmpty) {
      _logger.err('Option "$_androidFingerprint" can not be empty.');
      return ExitCode.usage.code;
    }

    if (outputPath.isEmpty) {
      _logger.err('Option "$_outputDirectoryName" can not be empty.');
      return ExitCode.usage.code;
    }

    String? teamId;

    /// Metadata processing
    String assetlinksMetadataWorkingDirectoryPath;

    if (commandArgResults.rest.isEmpty) {
      assetlinksMetadataWorkingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      assetlinksMetadataWorkingDirectoryPath = commandArgResults.rest[0];
    } else {
      _logger.err('Only one "$_directoryParameterName" parameter can be passed.');
      return ExitCode.usage.code;
    }

    // Create new metadata file if teamId is specified
    // or trying to read existed metadata file to get the teamId
    if (teamIdArg != null && teamIdArg.isNotEmpty) {
      teamId = teamIdArg;

      _logger.info('Creating working directory: $assetlinksMetadataWorkingDirectoryPath');
      Directory(assetlinksMetadataWorkingDirectoryPath).createSync(recursive: true);

      /// Well Known processing
      var welKnownWorkingDirectoryPath = outputPath;

      if (appendWellKnownDirectory) {
        welKnownWorkingDirectoryPath = path.join(welKnownWorkingDirectoryPath, _wellKnownPackage);
      }

      _logger.info('Creating working directory: $welKnownWorkingDirectoryPath');
      Directory(welKnownWorkingDirectoryPath).createSync(recursive: true);

      _logger.info('Writing Apple app site association to: $_appleAppSiteAssociation');

      final appleData = Mustache(map: {
        'appID': '$teamId.$bundleId',
      });
      final appleJSON = appleData.toStringifyJSON(StringifyAssets.appleAssetLinksTemplate);
      final appleFilePath = path.join(welKnownWorkingDirectoryPath, _appleAppSiteAssociation);
      File(appleFilePath).writeAsStringSync(appleJSON, flush: true);

      _logger.info('Writing Google asset links to: $_assetlinks');

      final googleData = Mustache(map: {
        'package_name': '$teamId.$bundleId',
        'sha256_cert_fingerprints': androidFingerprints,
      });
      final googleJSON = googleData.toStringifyJSON(StringifyAssets.androidAssetLinksTemplate);
      final googleFilePath = path.join(welKnownWorkingDirectoryPath, _assetlinks);
      File(googleFilePath).writeAsStringSync(googleJSON, flush: true);

      return ExitCode.success.code;
    } else {
      return ExitCode.usage.code;
    }
  }
}
