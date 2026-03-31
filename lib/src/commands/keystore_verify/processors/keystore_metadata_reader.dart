import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/keystore_generate/models/models.dart';

const _keystoreMetadataFileName = 'upload-keystore-metadata.json';

class KeystoreMetadataReader {
  const KeystoreMetadataReader({required this.logger});

  final Logger logger;

  KeystoreMetadata read({required String workingDirectoryPath}) {
    final metadataFilePath = path.join(workingDirectoryPath, _keystoreMetadataFileName);
    logger.info('Reading keystore metadata from: $metadataFilePath');
    return KeystoreMetadata.fromJson(File(metadataFilePath).readAsStringSync());
  }
}
