import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dto/application/application.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:simple_mustache/simple_mustache.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/gen/assets.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

const _applicationIdOptionName = 'applicationId';
const _directoryParameterName = '<directory>';

class KeystoreInitCommand extends Command<int> {
  KeystoreInitCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser.addOption(
      _applicationIdOptionName,
      help: 'Application ID to initialize the keystore project.',
      mandatory: true,
    );
  }

  @override
  String get name => 'keystore_init';

  @override
  String get description =>
      'Initialize a project with necessary keystore files and folders for signing the application.';

  final Logger _logger;

  final List<String> _existsKeystoreFiles = List.empty(growable: true);

  late final String _workingDirectoryPath;

  late final _datasource = DatasourceProvider(_logger);

  late final _readmeUpdater = KeystoreReadmeUpdater(_logger, _datasource);

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
      final url = '$configuratorApiUrl/api/v1/applications/$applicationId';
      application = await _datasource.getHttpData(url, ApplicationDTO.fromJsonString);
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
      _logger.info('Generating keystore using webtrit_phone_tools');
      final process = Process.runSync(
        'dart',
        [
          keystoreProjectPath,
          'keystore-generate',
          '--bundleId=${application.androidPlatformId ?? ''}',
        ],
        workingDirectory: keystoreProjectPath,
        runInShell: true,
      );

      if (process.exitCode == 0) {
        _logger
          ..info(process.stdout.toString())
          ..err(process.stderr.toString());

        _existsKeystoreFiles
          ..add(androidCredentials)
          ..add(androidUploadKeystoreJKS)
          ..add(androidUploadKeystoreP12);
      }
    }

    // Prepare base credentials template for ios auto deploy
    final dartDefineMapValues = {
      'BUNDLE_ID': application.iosPlatformId,
    };

    final credentialsIOSTemplate = Mustache(map: dartDefineMapValues);
    final dartDefine = credentialsIOSTemplate.convert(StringifyAssets.uploadStoreConnectMetadata).toMap();

    _datasource.writeFileData(
      path: path.join(keystoreProjectPath, '$iosCredentials.incomplete'),
      data: dartDefine.toJson(),
    );
    _existsKeystoreFiles.add(androidCredentials);

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
}
