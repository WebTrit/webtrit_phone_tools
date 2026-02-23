import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import '../constants/constants.dart';

class CertificateProcessor {
  const CertificateProcessor({required this.logger});

  final Logger logger;

  Future<void> process({
    required String projectKeystorePath,
    required String Function(String) resolvePath,
  }) async {
    final sslDir = Directory(path.join(projectKeystorePath, kSSLCertificatePath));

    if (!sslDir.existsSync()) {
      logger.warn('- Project SSL certificates directory does not exist.');
      return;
    }

    logger.info('- Processing SSL certificates...');
    final targetDir = Directory(resolvePath(assetSSLCertificate));
    if (!targetDir.existsSync()) await targetDir.create(recursive: true);

    await for (final entity in sslDir.list()) {
      if (entity is! File) continue;

      final newPath = path.join(targetDir.path, path.basename(entity.path));
      await entity.copy(newPath);
      logger.info('  Copy: ${entity.path} -> $newPath');
    }

    final credsFile = File(path.join(projectKeystorePath, kSSLCertificateCredentialPath));
    if (credsFile.existsSync()) {
      await credsFile.copy(path.join(targetDir.path, assetSSLCertificateCredentials));
      logger.info('  Copy: Credentials file.');
    }
  }
}
