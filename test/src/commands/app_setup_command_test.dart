import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_setup/app_setup_command.dart';
import 'package:webtrit_phone_tools/src/commands/app_setup/models/models.dart';
import 'package:webtrit_phone_tools/src/commands/app_setup/runners/runners.dart';

class _MockLogger extends Mock implements Logger {}

class _MockFirebaseSetupRunner extends Mock implements FirebaseSetupRunner {}

class _FakeAppSetupContext extends Fake implements AppSetupContext {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAppSetupContext());
  });

  late Logger logger;
  late _MockFirebaseSetupRunner mockRunner;
  late CommandRunner<int> commandRunner;
  late Directory tempDir;
  late Directory keystoreDir;
  late File cacheFile;

  setUp(() {
    logger = _MockLogger();
    mockRunner = _MockFirebaseSetupRunner();

    when(() => logger.info(any())).thenReturn(null);
    when(() => logger.err(any())).thenReturn(null);
    when(() => logger.success(any())).thenReturn(null);
    when(() => logger.detail(any())).thenReturn(null);

    commandRunner = CommandRunner<int>('test', 'test')
      ..addCommand(AppSetupCommand(logger: logger, firebaseSetupRunner: mockRunner));

    tempDir = Directory.systemTemp.createTempSync('app_setup_test_');
    keystoreDir = Directory('${tempDir.path}/keystore')..createSync();

    final serviceAccountDir = Directory('${keystoreDir.path}/build')..createSync();
    File('${serviceAccountDir.path}/google-play-service-account.json')
        .writeAsStringSync(jsonEncode({'project_id': 'test-firebase-project'}));

    cacheFile = File('${tempDir.path}/cache_session_data.json')
      ..writeAsStringSync(jsonEncode({'bundleIdAndroid': 'com.example.android', 'bundleIdIos': 'com.example.ios'}));
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('configurator-setup', () {
    test('returns usage exit code when --platform is not provided', () async {
      final result = await commandRunner.run([
        'configurator-setup',
        '--keystore-path',
        keystoreDir.path,
        tempDir.path,
      ]);
      expect(result, equals(ExitCode.usage.code));
    });

    test('returns usage exit code when keystore directory does not exist', () async {
      final result = await commandRunner.run([
        'configurator-setup',
        '--platform',
        'android',
        '--keystore-path',
        '${tempDir.path}/nonexistent',
        '--cache-session-data-path',
        cacheFile.path,
        tempDir.path,
      ]);
      expect(result, equals(ExitCode.usage.code));
    });

    test('returns usage exit code when cache session data file does not exist', () async {
      final result = await commandRunner.run([
        'configurator-setup',
        '--platform',
        'ios',
        '--keystore-path',
        keystoreDir.path,
        '--cache-session-data-path',
        '${tempDir.path}/missing.json',
        tempDir.path,
      ]);
      expect(result, equals(ExitCode.usage.code));
    });

    test('deduplicates repeated --platform values', () async {
      AppSetupContext? capturedContext;
      when(() => mockRunner.configure(any())).thenAnswer((invocation) async {
        capturedContext = invocation.positionalArguments[0] as AppSetupContext;
      });

      await commandRunner.run([
        'configurator-setup',
        '--platform',
        'ios',
        '--platform',
        'ios',
        '--keystore-path',
        keystoreDir.path,
        '--cache-session-data-path',
        cacheFile.path,
        tempDir.path,
      ]);

      expect(capturedContext?.platforms, equals([SetupPlatform.ios]));
    });

    test('succeeds and calls runner with correct platforms', () async {
      when(() => mockRunner.configure(any())).thenAnswer((_) async {});

      final result = await commandRunner.run([
        'configurator-setup',
        '--platform',
        'android',
        '--platform',
        'ios',
        '--keystore-path',
        keystoreDir.path,
        '--cache-session-data-path',
        cacheFile.path,
        tempDir.path,
      ]);

      expect(result, equals(ExitCode.success.code));
      verify(() => mockRunner.configure(any())).called(1);
    });

    test('returns data exit code when runner throws', () async {
      when(() => mockRunner.configure(any())).thenThrow(Exception('flutterfire failed'));

      final result = await commandRunner.run([
        'configurator-setup',
        '--platform',
        'android',
        '--keystore-path',
        keystoreDir.path,
        '--cache-session-data-path',
        cacheFile.path,
        tempDir.path,
      ]);

      expect(result, equals(ExitCode.data.code));
    });
  });
}
