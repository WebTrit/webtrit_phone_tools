import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:data/datasource/configurator_backend/configurator_bakcend.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/keystore_generate/models/models.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

import 'models/models.dart';
import 'processors/processors.dart';
import 'runners/runners.dart';
import 'services/services.dart';

const _applicationIdOptionName = 'applicationId';
const _directoryParameterName = '<directory>';
const _token = 'token';

class KeystoreInitCommand extends Command<int> {
  KeystoreInitCommand({
    required Logger logger,
    required ConfiguratorBackandDatasource datasource,
    required KeystoreReadmeUpdater keystoreReadmeUpdater,
  })  : _logger = logger,
        _datasource = datasource,
        _keystoreReadmeUpdater = keystoreReadmeUpdater {
    argParser
      ..addOption(
        _applicationIdOptionName,
        help: 'Application ID to initialize the keystore project.',
        mandatory: true,
      )
      ..addOption(
        _token,
        help: 'JWT token for  configurator API.',
        mandatory: true,
      );
  }

  @override
  String get name => 'keystore-init';

  @override
  String get description =>
      'Initialize a project with necessary keystore files and folders for signing the application.';

  final Logger _logger;
  final ConfiguratorBackandDatasource _datasource;
  final KeystoreReadmeUpdater _keystoreReadmeUpdater;

  @override
  Future<int> run() async {
    try {
      final context = _buildContext();

      final application = await ApplicationFetcher(
        datasource: _datasource,
        logger: _logger,
      ).fetch(
        applicationId: context.applicationId,
        authHeader: context.authHeader,
      );

      final keystoreProjectPath = path.join(context.workingDirectoryPath, 'applications', context.applicationId);

      final projectProcessor = KeystoreProjectProcessor(logger: _logger)
        ..createDirectoryStructure(
          keystoreProjectPath: keystoreProjectPath,
        );

      final existsKeystoreFiles = <String>[];

      // Add keystore for signing android build
      if (((application.androidPlatformId) ?? '').isNotEmpty) {
        await KeystoreGenerateRunner(logger: _logger).run(
          keystoreProjectPath: keystoreProjectPath,
          bundleId: application.androidPlatformId!,
        );

        existsKeystoreFiles.addAll([
          androidCredentials,
          androidUploadKeystoreJKS,
          androidUploadKeystoreP12,
        ]);
      }

      final uploadFingerprint = KeytoolRunner(logger: _logger).extractFingerprint(
        keystoreProjectPath: keystoreProjectPath,
      );
      if (uploadFingerprint != null) {
        await AssetlinksGenerateRunner(logger: _logger).run(
          keystoreProjectPath: keystoreProjectPath,
          iosPlatformId: application.iosPlatformId!,
          uploadFingerprint: uploadFingerprint,
        );
      }

      // Prepare base credentials template for ios auto deploy
      projectProcessor.writeIosCredentialsTemplate(
        keystoreProjectPath: keystoreProjectPath,
        iosPlatformId: application.iosPlatformId,
      );
      existsKeystoreFiles.add(iosCredentials);

      // Create incomplete files which still need attention
      projectProcessor.createStubFiles(
        keystoreProjectPath: keystoreProjectPath,
        existingKeystoreFiles: existsKeystoreFiles,
      );

      await ReadmeProcessor(
        keystoreReadmeUpdater: _keystoreReadmeUpdater,
        logger: _logger,
      ).updateReadme(
        workingDirectoryPath: context.workingDirectoryPath,
        applicationName: application.name ?? context.applicationId,
        applicationId: context.applicationId,
      );

      return ExitCode.success.code;
    } catch (e, s) {
      _logger
        ..err('Execution failed: $e')
        ..detail('$s');
      return ExitCode.usage.code;
    }
  }

  KeystoreInitContext _buildContext() {
    final commandArgResults = argResults!;

    String workingDirectoryPath;
    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      throw UsageException('Only one "$_directoryParameterName" parameter can be passed.', usage);
    }

    if (workingDirectoryPath.isEmpty) {
      throw UsageException('The working directory path cannot be empty.', usage);
    }

    final jwtToken = commandArgResults[_token] as String;
    if (jwtToken.isEmpty) {
      throw UsageException('Option "$_token" can not be empty.', usage);
    }

    final applicationId = commandArgResults[_applicationIdOptionName] as String;
    if (applicationId.isEmpty) {
      throw UsageException('Option "$_applicationIdOptionName" cannot be empty.', usage);
    }

    return KeystoreInitContext(
      workingDirectoryPath: workingDirectoryPath,
      applicationId: applicationId,
      authHeader: {'Authorization': 'Bearer $jwtToken'},
    );
  }
}
