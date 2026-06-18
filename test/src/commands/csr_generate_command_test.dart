import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/csr_generate/csr_generate.dart';

void main() {
  late Logger logger;
  late CommandRunner<int> commandRunner;

  setUp(() {
    logger = Logger();
    commandRunner = CommandRunner<int>('test', 'Test for CsrGenerateCommand')
      ..addCommand(CsrGenerateCommand(logger: logger));
  });

  test('should generate a private key and a certificate signing request', () async {
    final outputDirectory = Directory.systemTemp.createTempSync();
    final result = await commandRunner.run([
      'csr-generate',
      '--email',
      'app.admin@webtrit.com',
      '--commonName',
      'PortaDialer admin certificate request',
      outputDirectory.path,
    ]);

    expect(result, equals(0));
    expect(
      File(path.join(outputDirectory.path, 'CertificateSigningRequest.certSigningRequest')).existsSync(),
      isTrue,
    );
    expect(File(path.join(outputDirectory.path, 'CertificateSigningRequest.key')).existsSync(), isTrue);
  });

  test('should show usage error when email is empty', () async {
    final outputDirectory = Directory.systemTemp.createTempSync();
    final result = await commandRunner.run([
      'csr-generate',
      '--email',
      '',
      '--commonName',
      'PortaDialer admin certificate request',
      outputDirectory.path,
    ]);

    expect(result, equals(64)); // ExitCode.usage.code
  });

  test('should show usage error when keySize is not a positive integer', () async {
    final outputDirectory = Directory.systemTemp.createTempSync();
    final result = await commandRunner.run([
      'csr-generate',
      '--email',
      'app.admin@webtrit.com',
      '--commonName',
      'PortaDialer admin certificate request',
      '--keySize',
      'abc',
      outputDirectory.path,
    ]);

    expect(result, equals(64)); // ExitCode.usage.code
  });
}
