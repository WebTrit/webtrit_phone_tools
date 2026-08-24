import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/assetlinks_generate/assetlinks_generate.dart';

void main() {
  late Logger logger;
  late CommandRunner<int> commandRunner;

  setUp(() {
    logger = Logger();
    commandRunner = CommandRunner<int>('test', 'Test for AssetlinksGenerateCommand')
      ..addCommand(AssetlinksGenerateCommand(logger: logger));
  });

  test('names the Android package in the Android file, not the Apple one', () async {
    // Two brands in production carry different identifiers for the two stores,
    // and the file Android verifies has to name the package that signed the app.
    final outputDirectory = Directory.systemTemp.createTempSync();
    final result = await commandRunner.run([
      'assetlinks-generate',
      '--bundleId',
      'com.example.ios',
      '--androidBundleId',
      'com.example.android',
      '--appleTeamID',
      'TEAMID123',
      '--androidFingerprints',
      'ABC123',
      '--output',
      outputDirectory.path,
    ]);

    expect(result, equals(0));

    final google = File(path.join(outputDirectory.path, 'assetlinks.json')).readAsStringSync();
    expect(google, contains('com.example.android'));
    expect(google, isNot(contains('com.example.ios')));

    final apple = File(path.join(outputDirectory.path, 'apple-app-site-association.json')).readAsStringSync();
    expect(apple, contains('com.example.ios'));
  });

  test('writes the Android file for a brand that has no Apple identifier', () async {
    // Three brands in production have no iOS identifier at all. Having an
    // Android keystore says nothing about whether they do.
    final outputDirectory = Directory.systemTemp.createTempSync();
    final result = await commandRunner.run([
      'assetlinks-generate',
      '--bundleId',
      '',
      '--androidBundleId',
      'com.example.android',
      '--appleTeamID',
      'TEAMID123',
      '--androidFingerprints',
      'ABC123',
      '--output',
      outputDirectory.path,
    ]);

    expect(result, equals(0));
    expect(File(path.join(outputDirectory.path, 'assetlinks.json')).existsSync(), isTrue);
    expect(
      File(path.join(outputDirectory.path, 'apple-app-site-association.json')).existsSync(),
      isFalse,
      reason: 'nothing to associate without an identifier Apple would verify',
    );
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
