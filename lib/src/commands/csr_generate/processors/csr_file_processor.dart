import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import '../models/models.dart';

class CsrFileProcessor {
  const CsrFileProcessor({required this.logger});

  final Logger logger;

  void createWorkingDirectory({
    required String workingDirectoryPath,
    required bool createParentDirectories,
  }) {
    logger.info('Creating working directory: $workingDirectoryPath');
    Directory(workingDirectoryPath).createSync(recursive: createParentDirectories);
  }

  void writeOpensslLog({
    required String workingDirectoryPath,
    required ProcessResult processResult,
  }) {
    logger.info('Writing openssl execution log to: $opensslLogFileName');
    final opensslLogPath = path.join(workingDirectoryPath, opensslLogFileName);
    File(opensslLogPath)
      ..writeAsStringSync(processResult.stdout.toString(), flush: true)
      ..writeAsStringSync(processResult.stderr.toString(), mode: FileMode.append, flush: true);
  }
}
