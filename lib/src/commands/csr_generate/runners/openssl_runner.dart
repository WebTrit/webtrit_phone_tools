import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../models/models.dart';

class OpensslRunner {
  const OpensslRunner({required this.logger});

  final Logger logger;

  ProcessResult runGenerateCsr({
    required String workingDirectoryPath,
    required CsrGenerateContext context,
  }) {
    logger.info('Generating private key and certificate signing request to: $certificateSigningRequestFileName');
    final result = Process.runSync(
      'openssl',
      [
        'req',
        '-new',
        '-newkey',
        'rsa:${context.keySize}',
        '-nodes',
        '-keyout',
        privateKeyFileName,
        '-out',
        certificateSigningRequestFileName,
        '-subj',
        context.subject,
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
