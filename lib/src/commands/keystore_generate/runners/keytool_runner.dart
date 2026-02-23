import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/models/keystore_metadata.dart';

class KeytoolRunner {
  const KeytoolRunner({required this.logger});

  final Logger logger;

  ProcessResult runGenkeypair({
    required String workingDirectoryPath,
    required KeystoreMetadata metadata,
  }) {
    logger.info('Generating key pair using keytool to: ${metadata.storeFileJKS}');
    final result = Process.runSync(
      'keytool',
      [
        '-genkeypair',
        '-keyalg',
        'RSA',
        '-keysize',
        '2048',
        '-validity',
        '${365 * 50}',
        '-alias',
        metadata.keyAlias,
        '-keypass',
        metadata.keyPassword,
        '-keystore',
        metadata.storeFileJKS,
        '-storepass',
        metadata.storePassword,
        '-dname',
        metadata.dname,
        '-v',
      ],
      workingDirectory: workingDirectoryPath,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      logger
        ..info(result.stdout.toString())
        ..err(result.stderr.toString());
    }

    return result;
  }

  ProcessResult runImportKeystore({
    required String workingDirectoryPath,
    required KeystoreMetadata metadata,
  }) {
    logger.info('Transitioning to PKCS12 Format for KeyStore to: ${metadata.storeFileP12}');
    final result = Process.runSync(
      'keytool',
      [
        '-importkeystore',
        '-noprompt',
        '-srckeystore',
        metadata.storeFileJKS,
        '-srcstorepass',
        metadata.keyPassword,
        '-destkeystore',
        metadata.storeFileP12,
        '-deststoretype',
        'PKCS12',
        '-deststorepass',
        metadata.storePassword,
      ],
      workingDirectory: workingDirectoryPath,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      logger
        ..info(result.stdout.toString())
        ..err(result.stderr.toString());
    }

    return result;
  }
}
