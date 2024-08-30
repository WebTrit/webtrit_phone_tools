import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:mustache_template/mustache.dart';

import 'package:dto/application/application.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/commands/keystore_generate_command.dart';
import 'package:webtrit_phone_tools/src/commands/assetlinks_generate_command.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/gen/assets.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

const _applicationIdOptionName = 'applicationId';
const _directoryParameterName = '<directory>';

class KeystoreInitCommand extends Command<int> {
  KeystoreInitCommand({
    required Logger logger,
    required HttpClient httpClient,
    required KeystoreReadmeUpdater keystoreReadmeUpdater,
  })  : _logger = logger,
        _httpClient = httpClient,
        _readmeUpdater = keystoreReadmeUpdater,
        _commandRunner = CommandRunner<int>('tool', 'A tool to manage keystore')
          ..addCommand(KeystoreGenerateCommand(logger: logger))
          ..addCommand(AssetlinksGenerateCommand(logger: logger)) {
    argParser.addOption(
      _applicationIdOptionName,
      help: 'Application ID to initialize the keystore project.',
      mandatory: true,
    );
  }

  @override
  String get name => 'keystore-init';

  @override
  String get description =>
      'Initialize a project with necessary keystore files and folders for signing the application.';

  final Logger _logger;

  final HttpClient _httpClient;

  final KeystoreReadmeUpdater _readmeUpdater;

  final List<String> _existsKeystoreFiles = List.empty(growable: true);

  late final String _workingDirectoryPath;

  final CommandRunner<int> _commandRunner;

  @override
  Future<int> run() async {
    final commandArgResults = argResults!;

    if (commandArgResults.rest.isEmpty) {
      _workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      _workingDirectoryPath = commandArgResults.rest[0];
    } else {
      _logger.err('Only one "$_directoryParameterName" parameter can be passed.');
      return ExitCode.usage.code;
    }

    if (_workingDirectoryPath.isEmpty) {
      _logger.err('The working directory path cannot be empty.');
      return ExitCode.usage.code;
    }

    final applicationId = commandArgResults[_applicationIdOptionName] as String;
    if (applicationId.isEmpty) {
      _logger.err('Option "$_applicationIdOptionName" cannot be empty.');
      return ExitCode.usage.code;
    }

    ApplicationDTO application;
    try {
      application = await _httpClient.getApplication(applicationId);
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.usage.code;
    }

    _logger.info('Creating working directory: $_workingDirectoryPath');
    final keystoreProjectPath = path.join(_workingDirectoryPath, applicationId);
    Directory(keystoreProjectPath).createSync(recursive: true);

    _logger.info('Creating ssl certificates directory: $keystoreProjectPath');
    Directory(path.join(keystoreProjectPath, 'ssl_certificates')).createSync(recursive: true);

    // Add keystore for signing android build
    if (((application.androidPlatformId) ?? '').isNotEmpty) {
      await _commandRunner
          .run(['keystore-generate', '--bundleId', application.androidPlatformId!, keystoreProjectPath]);

      _existsKeystoreFiles.addAll([
        androidCredentials,
        androidUploadKeystoreJKS,
        androidUploadKeystoreP12,
      ]);
    }

    final uploadFingerprint = _getKeystoreFingerprint(keystoreProjectPath);
    if (uploadFingerprint != null) {
      final command = [
        'assetlinks-generate',
        '--bundleId',
        application.iosPlatformId!,
        '--androidFingerprints',
        uploadFingerprint,
        '--appleTeamID',
        'test',
        '--output',
        path.join(keystoreProjectPath, 'deep_links'),
        '--appendWellKnowDirectory',
        keystoreProjectPath
      ];
      await _commandRunner.run(command);
    }

    // Prepare base credentials template for ios auto deploy
    final credentialsIOSMapValues = {
      'BUNDLE_ID': application.iosPlatformId,
    };

    final credentialsIOSTemplate = Template(StringifyAssets.uploadStoreConnectMetadata, htmlEscapeValues: false);
    final credentialsIOS = credentialsIOSTemplate.renderAndCleanJson(credentialsIOSMapValues);
    final iosCredentialsFilePath = path.join(keystoreProjectPath, '$iosCredentials.incomplete');

    File(iosCredentialsFilePath).writeAsStringSync(credentialsIOS.toJson());
    _existsKeystoreFiles.add(iosCredentials);

    // Create incomplete files which still need attention
    for (final fileName in keystoreFiles) {
      if (!_existsKeystoreFiles.contains(fileName)) {
        final filePath = path.join(keystoreProjectPath, '$fileName.incomplete');
        _logger.info('Creating empty file: $filePath');
        File(filePath).createSync();
      }
    }

    await _readmeUpdater.addApplicationRecord(
      _workingDirectoryPath,
      application.name ?? applicationId,
      applicationId,
    );
    return ExitCode.success.code;
  }

  String? _getKeystoreFingerprint(String keystoreProjectPath) {
    final metadataFile = File(path.join(keystoreProjectPath, 'upload-keystore-metadata.json'));
    if (metadataFile.existsSync()) {
      final metadata = jsonDecode(metadataFile.readAsStringSync()) as Map<String, dynamic>;
      final keyPassword = metadata['keyPassword'];
      final storeFileP12 = metadata['storeFile'];

      final command = [
        '-c',
        'keytool -list -v -keystore $storeFileP12 -storetype PKCS12 -storepass $keyPassword | grep SHA256'
      ];
      final process = Process.runSync(
        'sh',
        command,
        workingDirectory: keystoreProjectPath,
        runInShell: true,
      );

      if (process.exitCode == 0) {
        final output = process.stdout as String;
        final regex = RegExp(r'SHA256:\s*([\w:]+)');
        final match = regex.firstMatch(output);
        if (match != null) {
          return match.group(1);
        } else {
          _logger.err('SHA256 hash not found in the output.');
        }
      } else {
        _logger.err('Error running keytool command: ${process.stderr ?? process.stdout}, command: $command');
      }
    } else {
      _logger.err('Keystore not provided.');
    }
    return null;
  }
}
