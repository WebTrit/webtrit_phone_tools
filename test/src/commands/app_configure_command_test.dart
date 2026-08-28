import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_configure/app_configure_command.dart';
import 'package:webtrit_phone_tools/src/commands/app_configure/runners/runners.dart';

class _MockLogger extends Mock implements Logger {}

class _MockProgress extends Mock implements Progress {}

/// Records which generator was asked to run, and in what order.
class _RecordingFlutter implements FlutterRunner {
  _RecordingFlutter(this.calls, {this.failOn});

  final List<String> calls;
  final String? failOn;

  Future<void> _record(String name) async {
    calls.add(name);
    if (name == failOn) throw Exception('$name refused');
  }

  @override
  Future<void> setupDependencies(String workingDirectory) => _record('dependencies');

  @override
  Future<void> configureLocalization(String workingDirectory) => _record('localization');

  @override
  Future<void> configureAssets(String workingDirectory) => _record('assets');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// Turning what a build fetched into what a build ships.
///
/// This step reads no service and decides nothing about a brand: it hands the
/// files the previous step wrote to the generators that turn them into icons, a
/// splash screen, native identifiers and localizations. So what is worth
/// holding is which generators run, in what order, and what happens when one
/// refuses - none of which needed a real build to check, and none of which was
/// checked at all until now.
void main() {
  late Logger logger;
  late Directory checkout;
  late List<String> calls;

  Future<int?> runConfigure({String? flutterFails}) async {
    final runner = CommandRunner<int>('test', 'test')
      ..addCommand(AppConfigureCommand(
        logger: logger,
        flutterRunner: _RecordingFlutter(calls, failOn: flutterFails),
      ));
    return runner.run(['configurator-generate', checkout.path]);
  }

  setUp(() {
    logger = _MockLogger();
    when(() => logger.info(any())).thenReturn(null);
    when(() => logger.err(any())).thenReturn(null);
    when(() => logger.detail(any())).thenReturn(null);
    when(() => logger.success(any())).thenReturn(null);
    when(() => logger.progress(any())).thenReturn(_MockProgress());

    calls = [];
    checkout = Directory.systemTemp.createTempSync('app_configure_test_');
    final keystore = Directory(p.join(checkout.path, 'keystore'))..createSync(recursive: true);
    Directory(p.join(keystore.path, 'build')).createSync(recursive: true);
    File(p.join(keystore.path, 'build', 'google-play-service-account.json'))
        .writeAsStringSync('{"project_id": "a-brand-project"}');
    File(p.join(checkout.path, 'cache_session_data.json')).writeAsStringSync(
      '{"keystore_path": "${keystore.path}", "bundleIdAndroid": "com.brand.one", "bundleIdIos": "com.brand.one"}',
    );
  });

  tearDown(() => checkout.deleteSync(recursive: true));

  test('runs every generator a branded build needs', () async {
    final exitCode = await runConfigure();

    expect(exitCode, ExitCode.success.code);
    expect(calls, ['dependencies', 'localization', 'assets']);
  });

  test('installs dependencies before anything reads them', () async {
    // The generators are packages themselves; running one before the checkout
    // has its dependencies is a failure about a missing tool rather than about
    // the brand, and it is confusing enough to be worth pinning.
    await runConfigure();

    expect(calls.first, 'dependencies');
  });

  test('stops when a step refuses, rather than reporting success', () async {
    final exitCode = await runConfigure(flutterFails: 'localization');

    expect(exitCode, isNot(ExitCode.success.code));
    expect(calls, ['dependencies', 'localization']);
  });

  test('says which step refused', () async {
    await runConfigure(flutterFails: 'localization');

    final said = verify(() => logger.err(captureAny())).captured.join('\n');
    expect(said, contains('localization refused'));
  });
}
