import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/csr_finalize/csr_finalize.dart';

void main() {
  late Logger logger;
  late CommandRunner<int> commandRunner;

  setUp(() {
    logger = Logger();
    commandRunner = CommandRunner<int>('test', 'Test for CsrFinalizeCommand')
      ..addCommand(CsrFinalizeCommand(logger: logger));
  });

  Directory createKeystoreDirectory() {
    final directory = Directory.systemTemp.createTempSync();
    final pemPath = path.join(directory.path, 'certificate.pem');
    final keyPath = path.join(directory.path, 'CertificateSigningRequest.key');
    Process.runSync(
      'openssl',
      [
        'req', '-new', '-newkey', 'rsa:2048', '-nodes', '-keyout', keyPath, //
        '-x509', '-days', '1', '-subj', '/CN=iPhone Distribution: Test', '-out', pemPath,
      ],
      runInShell: true,
    );
    Process.runSync(
      'openssl',
      ['x509', '-in', pemPath, '-outform', 'DER', '-out', path.join(directory.path, 'ios_distribution.cer')],
      runInShell: true,
    );
    File(path.join(directory.path, 'upload-store-connect-metadata.json'))
        .writeAsStringSync('{"bundleId": "com.example.app"}');
    return directory;
  }

  test('should build a PKCS12 bundle and write the code signing identity', () async {
    final directory = createKeystoreDirectory();
    final result = await commandRunner.run([
      'csr-finalize',
      '--cert',
      'ios_distribution.cer',
      directory.path,
    ]);

    expect(result, equals(0));
    expect(File(path.join(directory.path, 'Certificates.p12')).existsSync(), isTrue);

    final metadata = jsonDecode(
      File(path.join(directory.path, 'upload-store-connect-metadata.json')).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(metadata['bundleId'], equals('com.example.app'));
    expect(metadata['code-signing-identity'], matches(RegExp(r'^[0-9A-F]{40}$')));
  });

  test('should show usage error when the certificate is missing', () async {
    final directory = createKeystoreDirectory();
    final result = await commandRunner.run([
      'csr-finalize',
      '--cert',
      'does_not_exist.cer',
      directory.path,
    ]);

    expect(result, equals(64)); // ExitCode.usage.code
    expect(File(path.join(directory.path, 'Certificates.p12')).existsSync(), isFalse);
  });
}
