import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:mustache_template/mustache.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';

import '../gen/assets.dart';

const _bundleIdOptionName = 'bundleId';
const _appleTeamIDOptionName = 'appleTeamID';
const _androidFingerprints = 'androidFingerprints';

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
        defaultsTo: '',
      )
      ..addMultiOption(
        _androidFingerprints,
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
        defaultsTo: '',
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
        'Generate a .well-known files for configuration applinks in the WebTrit Phone Android and iOS applications.',
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
    final androidFingerprints = commandArgResults[_androidFingerprints] as List<String>;
    final outputPath = commandArgResults[_outputDirectoryName] as String;
    final teamIdArg = commandArgResults[_appleTeamIDOptionName] as String;
    final appendWellKnownDirectory = commandArgResults[_appendWellKnowDirectory] as bool;

    final isGenerateGoogleAssetLinks = androidFingerprints.isNotEmpty;
    final isGenerateAppleAssetLinks = teamIdArg.isNotEmpty && bundleId.isNotEmpty;

    if (!isGenerateGoogleAssetLinks && !isGenerateAppleAssetLinks) {
      _logger.err(
          'At least one of "$_androidFingerprints" or "$_appleTeamIDOptionName" && "$_bundleIdOptionName" must be provided.');
      return ExitCode.usage.code;
    }

    if (outputPath.isEmpty) {
      _logger.err('Option "$_outputDirectoryName" can not be empty.');
      return ExitCode.usage.code;
    }

    /// Well Known processing
    var welKnownWorkingDirectoryPath = outputPath;

    if (appendWellKnownDirectory) {
      welKnownWorkingDirectoryPath = path.join(welKnownWorkingDirectoryPath, _wellKnownPackage);
    }

    _logger.info('Creating working directory: $welKnownWorkingDirectoryPath');
    Directory(welKnownWorkingDirectoryPath).createSync(recursive: true);

    if (isGenerateAppleAssetLinks) {
      _logger.info('Writing Apple app site association to: $_appleAppSiteAssociation');

      final appleAssetlinksMapValues = {
        'appID': '$teamIdArg.$bundleId',
      };

      final appleAssetlinksTemplate = Template(StringifyAssets.appleAssetLinksTemplate, htmlEscapeValues: false);
      final appleAssetlinks = appleAssetlinksTemplate.renderString(appleAssetlinksMapValues);
      final appleAssetlinksFilePath = path.join(welKnownWorkingDirectoryPath, _appleAppSiteAssociation);

      File(appleAssetlinksFilePath).writeAsStringSync(appleAssetlinks, flush: true);
      _logger
        ..info(appleAssetlinks)
        ..success('Apple Assetlinks successfully created.');
    } else {
      _logger.warn('Apple Team ID is not provided. Skipping Apple app site association.');
    }

    if (isGenerateGoogleAssetLinks) {
      _logger.info('Writing Google asset links to: $_assetlinks');

      final googleAssetlinksMapValues = {
        'package_name': bundleId,
        'sha256_cert_fingerprints': '[${androidFingerprints.map((fp) => '"$fp"').join(', ')}]',
      };

      final googleAssetlinksTemplate = Template(StringifyAssets.googleAssetLinksTemplate, htmlEscapeValues: false);
      final googleAssetlinks = googleAssetlinksTemplate.renderAndCleanJson(googleAssetlinksMapValues);
      final googleAssetlinksFilePath = path.join(welKnownWorkingDirectoryPath, _assetlinks);

      File(googleAssetlinksFilePath).writeAsStringSync(googleAssetlinks, flush: true);
      _logger
        ..info(googleAssetlinks)
        ..success('Google Assetlinks successfully created.');
    } else {
      _logger.warn('Android Fingerprints are not provided. Skipping Google asset links.');
    }

    return ExitCode.success.code;
  }
}
