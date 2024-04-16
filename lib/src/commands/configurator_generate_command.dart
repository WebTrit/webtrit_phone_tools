import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';

const _keystorePath = 'keystore-path';

const _directoryParameterName = '<directory>';
const _firebaseServiceAccountFileName = 'firebase-service-account.json';

class ConfiguratorGenerateCommand extends Command<int> {
  ConfiguratorGenerateCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser.addOption(
      _keystorePath,
      help: "Path to the project's keystore folder.",
    );
  }

  @override
  String get name => 'configurator-generate';

  @override
  String get description {
    final buffer = StringBuffer()
      ..writeln(
        'Generate resources for customize application',
      );
    return buffer.toString();
  }

  final Logger _logger;

  late String workingDirectoryPath;

  @override
  Future<int> run() async {
    final commandArgResults = argResults!;

    if (commandArgResults.rest.isEmpty) {
      workingDirectoryPath = Directory.current.path;
    } else if (commandArgResults.rest.length == 1) {
      workingDirectoryPath = commandArgResults.rest[0];
    } else {
      _logger.err('Only one "$_directoryParameterName" parameter can be passed.');
      return ExitCode.usage.code;
    }

    final buildConfig = _readData(_workingDirectory(relativePath: buildConfigFile)).toMap();

    final projectKeystorePathArg = commandArgResults[_keystorePath] as String?;
    final projectKeystorePathBuildConfig = buildConfig[keystorePathField] as String?;
    final projectKeystorePath = projectKeystorePathArg ?? projectKeystorePathBuildConfig ?? '';

    if (projectKeystorePath.isEmpty) {
      _logger.err(
        'The option $_keystorePath cannot be empty and must be provided as a parameter or through $buildConfigFile',
      );
      return ExitCode.usage.code;
    }

    _logger.info('- Keystore path: $projectKeystorePath');

    if (!Directory(projectKeystorePath).existsSync()) {
      _logger.err('- Directory does not exist: $projectKeystorePath');
      return ExitCode.data.code;
    }

    if ((Directory(projectKeystorePath).statSync().mode & 0x124) == 0) {
      _logger.err('- No read permissions for file: $projectKeystorePath');
      return ExitCode.data.code;
    }

    final firebaseServiceAccountPath = path.join(projectKeystorePath, _firebaseServiceAccountFileName);
    final firebaseServiceAccount = _readData(firebaseServiceAccountPath).toMap();
    final firebaseAccountId = firebaseServiceAccount[projectIdField];

    _logger
      ..info('- Service account path: $firebaseServiceAccountPath')
      ..info('Configure $firebaseAccountId google services');
    final process = await Process.run(
      'flutterfire',
      [
        'configure',
        '--yes',
        '--project=$firebaseAccountId',
        '--service-account=$firebaseServiceAccountPath',
      ],
    );

    _logger
      ..info(process.stdout.toString())
      ..err(process.stderr.toString())
      ..info('flutterfire finished with: ${process.exitCode}');

    _logger.info('Flutter gen start');
    final flutterGenProcess = await Process.run(
      'fluttergen',
      [],
      workingDirectory: _workingDirectory(),
    );
    _logger
      ..info(flutterGenProcess.stdout.toString())
      ..err(flutterGenProcess.stderr.toString())
      ..info('Flutter gen finished with: ${flutterGenProcess.exitCode}');

    final flutterIconsProcess = await Process.run(
      'flutter',
      [
        'pub',
        'run',
        'flutter_launcher_icons',
      ],
      workingDirectory: _workingDirectory(),
    );
    _logger
      ..info(flutterIconsProcess.stdout.toString())
      ..err(flutterIconsProcess.stderr.toString())
      ..info('Flutter icons generation finished with: ${flutterIconsProcess.exitCode}');

    final nativeSplashProcess = await Process.run(
      'dart',
      [
        'run',
        'flutter_native_splash:create',
      ],
      workingDirectory: _workingDirectory(),
    );
    _logger
      ..info(nativeSplashProcess.stdout.toString())
      ..err(nativeSplashProcess.stderr.toString())
      ..info('Native splash generation finished with: ${nativeSplashProcess.exitCode}');

    final packageInstallProcess = await Process.run(
      'dart',
      [
        'pub',
        'add',
        'package_rename',
      ],
      workingDirectory: _workingDirectory(),
    );
    _logger
      ..info(packageInstallProcess.stdout.toString())
      ..err(packageInstallProcess.stderr.toString())
      ..info('Package renaming finished with: ${packageInstallProcess.exitCode}');

    final packageRenameProcess = await Process.run(
      'dart',
      [
        'run',
        'package_rename',
      ],
      workingDirectory: _workingDirectory(),
    );
    _logger
      ..info(packageRenameProcess.stdout.toString())
      ..err(packageRenameProcess.stderr.toString())
      ..info('Package renaming finished with: ${packageRenameProcess.exitCode}');

    final buildRunnerProcess = await Process.run(
      'flutter',
      [
        'pub',
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ],
      workingDirectory: _workingDirectory(),
    );
    _logger
      ..info(buildRunnerProcess.stdout.toString())
      ..err(buildRunnerProcess.stderr.toString())
      ..info('Build runner finished with: ${buildRunnerProcess.exitCode}');

    return ExitCode.success.code;
  }

  String _workingDirectory({String relativePath = ''}) {
    return path.join(workingDirectoryPath, relativePath);
  }

  String _readData(String path) {
    return File(path).readAsStringSync();
  }
}
