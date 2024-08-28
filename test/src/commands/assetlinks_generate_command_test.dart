import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/assetlinks_generate_command.dart';

void main() {
  late Logger logger;
  late CommandRunner<int> commandRunner;

  setUp(() {
    logger = Logger();
    commandRunner = CommandRunner<int>('test', 'Test for AssetlinksGenerateCommand')
      ..addCommand(AssetlinksGenerateCommand(logger: logger));
  });

  test('should generate both Apple and Google asset links', () async {
    final outputDirectory = Directory.systemTemp.createTempSync();
    final result = await commandRunner.run([
      'assetlinks-generate',
      '--bundleId',
      'com.example.app',
      '--appleTeamID',
      'TEAMID123',
      '--androidFingerprints',
      'ABC123,DEF456',
      '--output',
      outputDirectory.path,
      '--appendWellKnowDirectory'
    ]);

    expect(result, equals(0));

    final wellKnownPath = path.join(outputDirectory.path, '.well-known');
    expect(File(path.join(wellKnownPath, 'apple-app-site-association.json')).existsSync(), isTrue);
    expect(File(path.join(wellKnownPath, 'assetlinks.json')).existsSync(), isTrue);
  });

  test('should generate only Google asset links', () async {
    final outputDirectory = Directory.systemTemp.createTempSync();
    final result = await commandRunner.run([
      'assetlinks-generate',
      '--bundleId',
      'com.example.app',
      '--androidFingerprints',
      'ABC123,DEF456',
      '--output',
      outputDirectory.path,
      '--appendWellKnowDirectory'
    ]);

    expect(result, equals(0));

    final wellKnownPath = path.join(outputDirectory.path, '.well-known');
    expect(File(path.join(wellKnownPath, 'assetlinks.json')).existsSync(), isTrue);
    expect(File(path.join(wellKnownPath, 'apple-app-site-association.json')).existsSync(), isFalse);
  });

  test('should generate only Apple asset links', () async {
    final outputDirectory = Directory.systemTemp.createTempSync();
    final result = await commandRunner.run([
      'assetlinks-generate',
      '--bundleId',
      'com.example.app',
      '--appleTeamID',
      'TEAMID123',
      '--output',
      outputDirectory.path,
      '--appendWellKnowDirectory'
    ]);

    expect(result, equals(0));

    final wellKnownPath = path.join(outputDirectory.path, '.well-known');
    expect(File(path.join(wellKnownPath, 'apple-app-site-association.json')).existsSync(), isTrue);
    expect(File(path.join(wellKnownPath, 'assetlinks.json')).existsSync(), isFalse);
  });

  test('should show error if no Apple or Google configuration is provided', () async {
    final outputDirectory = Directory.systemTemp.createTempSync();
    final result = await commandRunner.run([
      'assetlinks-generate',
      '--bundleId',
      'com.example.app',
      '--output',
      outputDirectory.path,
      '--appendWellKnowDirectory'
    ]);

    expect(result, equals(64)); // ExitCode.usage.code

    final wellKnownPath = path.join(outputDirectory.path, '.well-known');
    expect(File(path.join(wellKnownPath, 'apple-app-site-association.json')).existsSync(), isFalse);
    expect(File(path.join(wellKnownPath, 'assetlinks.json')).existsSync(), isFalse);
  });
}
