import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mustache_template/mustache.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/extension/extension.dart';
import 'package:webtrit_phone_tools/src/gen/assets.dart';

const _appleAppSiteAssociation = 'apple-app-site-association.json';
const _assetlinks = 'assetlinks.json';
const _wellKnownPackage = '.well-known';

class AssetlinksFileProcessor {
  const AssetlinksFileProcessor({required this.logger});

  final Logger logger;

  void createWorkingDirectory({
    required String outputPath,
    required bool appendWellKnown,
  }) {
    var directoryPath = outputPath;
    if (appendWellKnown) {
      directoryPath = path.join(directoryPath, _wellKnownPackage);
    }
    logger.info('Creating working directory: $directoryPath');
    Directory(directoryPath).createSync(recursive: true);
  }

  String resolveOutputPath({
    required String outputPath,
    required bool appendWellKnown,
  }) {
    if (appendWellKnown) {
      return path.join(outputPath, _wellKnownPackage);
    }
    return outputPath;
  }

  void writeAppleAppSiteAssociation({
    required String outputDirectoryPath,
    required String teamId,
    required String bundleId,
  }) {
    logger.info('Writing Apple app site association to: $_appleAppSiteAssociation');

    final appleAssetlinksMapValues = {
      'appID': '$teamId.$bundleId',
    };

    final appleAssetlinksTemplate = Template(StringifyAssets.appleAssetLinksTemplate, htmlEscapeValues: false);
    final appleAssetlinks = appleAssetlinksTemplate.renderString(appleAssetlinksMapValues);
    final appleAssetlinksFilePath = path.join(outputDirectoryPath, _appleAppSiteAssociation);

    File(appleAssetlinksFilePath).writeAsStringSync(appleAssetlinks, flush: true);
    logger
      ..info(appleAssetlinks)
      ..success('Apple Assetlinks successfully created.');
  }

  void writeGoogleAssetLinks({
    required String outputDirectoryPath,
    required String bundleId,
    required List<String> androidFingerprints,
  }) {
    logger.info('Writing Google asset links to: $_assetlinks');

    final googleAssetlinksMapValues = {
      'package_name': bundleId,
      'sha256_cert_fingerprints': '[${androidFingerprints.map((fp) => '"$fp"').join(', ')}]',
    };

    final googleAssetlinksTemplate = Template(StringifyAssets.googleAssetLinksTemplate, htmlEscapeValues: false);
    final googleAssetlinks = googleAssetlinksTemplate.renderAndCleanJson(googleAssetlinksMapValues).toStringifyJson();
    final googleAssetlinksFilePath = path.join(outputDirectoryPath, _assetlinks);

    File(googleAssetlinksFilePath).writeAsStringSync(googleAssetlinks, flush: true);
    logger
      ..info(googleAssetlinks)
      ..success('Google Assetlinks successfully created.');
  }
}
