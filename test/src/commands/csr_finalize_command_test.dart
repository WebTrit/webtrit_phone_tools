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
    final pkcs12Path = path.join(directory.path, 'Certificates.p12');
    expect(File(pkcs12Path).existsSync(), isTrue);

    // On macOS the bundle must import with an empty password — this is exactly
    // what `yukiarrr/ios-build-action` does, and what the OpenSSL-only bundle
    // failed with ("MAC verification failed during PKCS12 import").
    if (Platform.isMacOS) {
      final keychainPath = path.join(directory.path, 'verify.keychain');
      Process.runSync('security', ['create-keychain', '-p', 'verify', keychainPath], runInShell: true);
      final import = Process.runSync(
        'security',
        ['import', pkcs12Path, '-k', keychainPath, '-P', ''],
        runInShell: true,
      );
      Process.runSync('security', ['delete-keychain', keychainPath], runInShell: true);
      expect(import.exitCode, equals(0), reason: 'security import failed: ${import.stderr}');
    }

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
