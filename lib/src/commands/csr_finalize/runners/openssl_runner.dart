import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

class OpensslRunner {
  const OpensslRunner({required this.logger});

  final Logger logger;

  bool convertCertificateToPem({
    required String certificatePath,
    required String pemPath,
  }) {
    logger.info('Converting certificate to PEM');
    for (final inputFormat in const ['DER', 'PEM']) {
      final result = Process.runSync(
        'openssl',
        ['x509', '-inform', inputFormat, '-in', certificatePath, '-out', pemPath],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        return true;
      }
    }
    logger.err('Failed to read certificate: $certificatePath');
    return false;
  }

  ProcessResult buildPkcs12({
    required String pemPath,
    required String privateKeyPath,
    required String pkcs12Path,
    required String password,
  }) {
    logger.info('Building PKCS12 bundle to: $pkcs12Path');
    final result = Process.runSync(
      'openssl',
      [
        'pkcs12',
        '-export',
        '-inkey',
        privateKeyPath,
        '-in',
        pemPath,
        '-out',
        pkcs12Path,
        '-passout',
        'pass:$password',
      ],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      logger
        ..info(result.stdout.toString())
        ..err(result.stderr.toString());
    }

    return result;
  }

  String? extractCodeSigningIdentity({required String pemPath}) {
    final result = Process.runSync(
      'openssl',
      ['x509', '-in', pemPath, '-noout', '-fingerprint', '-sha1'],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      logger.err('Failed to compute certificate fingerprint: ${result.stderr}');
      return null;
    }

    final output = result.stdout.toString();
    final delimiterIndex = output.indexOf('=');
    if (delimiterIndex == -1) {
      logger.err('SHA1 fingerprint not found in the output.');
      return null;
    }

    final identity =
        output.substring(delimiterIndex + 1).replaceAll(':', '').replaceAll(RegExp(r'\s'), '').toUpperCase();
    return identity.isEmpty ? null : identity;
  }
}
