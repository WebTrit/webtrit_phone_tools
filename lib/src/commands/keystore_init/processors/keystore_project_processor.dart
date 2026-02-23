import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mustache_template/mustache.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/commands/keystore_generate/models/models.dart';
import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/gen/assets.dart';

class KeystoreProjectProcessor {
  const KeystoreProjectProcessor({required this.logger});

  final Logger logger;

  void createDirectoryStructure({
    required String keystoreProjectPath,
  }) {
    logger.info('Creating working directory: $keystoreProjectPath');
    Directory(keystoreProjectPath).createSync(recursive: true);

    logger.info('Creating ssl certificates directory: $keystoreProjectPath');
    Directory(path.join(keystoreProjectPath, 'ssl_certificates')).createSync(recursive: true);
  }

  void writeIosCredentialsTemplate({
    required String keystoreProjectPath,
    required String? iosPlatformId,
  }) {
    final credentialsIOSMapValues = {
      'BUNDLE_ID': iosPlatformId,
    };

    final credentialsIOSTemplate = Template(StringifyAssets.uploadStoreConnectMetadata, htmlEscapeValues: false);
    final credentialsIOS = credentialsIOSTemplate.renderAndCleanJson(credentialsIOSMapValues);
    final iosCredentialsFilePath = path.join(keystoreProjectPath, '$iosCredentials.incomplete');

    File(iosCredentialsFilePath).writeAsStringSync(credentialsIOS.toStringifyJson());
  }

  void createStubFiles({
    required String keystoreProjectPath,
    required List<String> existingKeystoreFiles,
  }) {
    for (final fileName in keystoreFiles) {
      if (!existingKeystoreFiles.contains(fileName)) {
        final filePath = path.join(keystoreProjectPath, '$fileName.incomplete');
        logger.info('Creating empty file: $filePath');
        File(filePath).createSync();
      }
    }
  }
}
