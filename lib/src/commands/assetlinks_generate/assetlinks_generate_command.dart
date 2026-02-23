import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';

import 'models/models.dart';
import 'processors/processors.dart';

const _bundleIdOptionName = 'bundleId';
const _appleTeamIDOptionName = 'appleTeamID';
const _androidFingerprints = 'androidFingerprints';
const _outputDirectoryName = 'output';
const _appendWellKnowDirectory = 'appendWellKnowDirectory';
const _directoryParameterName = '<directory>';
const _directoryParameterDescriptionName = '$_directoryParameterName (optional)';

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
    try {
      final context = _buildContext();

      final fileProcessor = AssetlinksFileProcessor(logger: _logger)
        ..createWorkingDirectory(
        outputPath: context.outputPath,
        appendWellKnown: context.appendWellKnown,
      );

      final outputDirectoryPath = fileProcessor.resolveOutputPath(
        outputPath: context.outputPath,
        appendWellKnown: context.appendWellKnown,
      );

      final isGenerateGoogleAssetLinks = context.androidFingerprints.isNotEmpty;
      final isGenerateAppleAssetLinks = context.teamId.isNotEmpty && context.bundleId.isNotEmpty;

      if (isGenerateAppleAssetLinks) {
        fileProcessor.writeAppleAppSiteAssociation(
          outputDirectoryPath: outputDirectoryPath,
          teamId: context.teamId,
          bundleId: context.bundleId,
        );
      } else {
        _logger.warn('Apple Team ID is not provided. Skipping Apple app site association.');
      }

      if (isGenerateGoogleAssetLinks) {
        fileProcessor.writeGoogleAssetLinks(
          outputDirectoryPath: outputDirectoryPath,
          bundleId: context.bundleId,
          androidFingerprints: context.androidFingerprints,
        );
      } else {
        _logger.warn('Android Fingerprints are not provided. Skipping Google asset links.');
      }

      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.usage.code;
    }
  }

  AssetlinksGenerateContext _buildContext() {
    final commandArgResults = argResults!;
    final bundleId = commandArgResults[_bundleIdOptionName] as String;
    final androidFingerprints = commandArgResults[_androidFingerprints] as List<String>;
    final outputPath = commandArgResults[_outputDirectoryName] as String;
    final teamId = commandArgResults[_appleTeamIDOptionName] as String;
    final appendWellKnown = commandArgResults[_appendWellKnowDirectory] as bool;

    final isGenerateGoogleAssetLinks = androidFingerprints.isNotEmpty;
    final isGenerateAppleAssetLinks = teamId.isNotEmpty && bundleId.isNotEmpty;

    if (!isGenerateGoogleAssetLinks && !isGenerateAppleAssetLinks) {
      throw UsageException(
        'At least one of "$_androidFingerprints" or "$_appleTeamIDOptionName" && "$_bundleIdOptionName" must be provided.',
        usage,
      );
    }

    if (outputPath.isEmpty) {
      throw UsageException('Option "$_outputDirectoryName" can not be empty.', usage);
    }

    return AssetlinksGenerateContext(
      bundleId: bundleId,
      androidFingerprints: androidFingerprints,
      outputPath: outputPath,
      teamId: teamId,
      appendWellKnown: appendWellKnown,
    );
  }
}
