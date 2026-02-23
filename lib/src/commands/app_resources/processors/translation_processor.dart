import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../constants/constants.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

class TranslationProcessor {
  const TranslationProcessor({
    required this.httpClient,
    required this.logger,
  });

  final HttpClient httpClient;
  final Logger logger;

  Future<void> process({
    required String applicationId,
    required String Function(String) resolvePath,
  }) async {
    final configFile = File(resolvePath('localizely.yml'));

    if (!configFile.existsSync()) {
      logger.warn('localizely.yml file not found in the working directory.');
      return;
    }

    final localeCodes = <String>{};

    try {
      final yamlString = await configFile.readAsString();
      final config = loadYaml(yamlString) as YamlMap;
      final downloadConfig = config['download'] as YamlMap;
      final filesConfig = downloadConfig['files'] as YamlList;

      for (final item in filesConfig.cast<YamlMap>()) {
        final localeCode = item['locale_code'] as String?;
        if (localeCode != null && localeCode.isNotEmpty) {
          localeCodes.add(localeCode);
        } else {
          logger.warn('Skipping file entry: missing or invalid "locale_code".');
        }
      }
    } on YamlException catch (e) {
      logger.err('Failed to parse localizely.yml: ${e.message}');
      return;
    } catch (e) {
      logger.err('Invalid structure in localizely.yml: $e');
      return;
    }

    if (localeCodes.isEmpty) {
      logger.warn('No valid locale codes found to download.');
      return;
    }

    logger.info('Downloading translations for: ${localeCodes.join(', ')}');
    final zipFiles = await httpClient.getTranslationFiles(applicationId);

    for (final file in zipFiles) {
      final fileName = p.basename(file.name);

      if (fileName.isEmpty || fileName != file.name) {
        logger.detail('Skipping suspicious file path: ${file.name}');
        continue;
      }

      final locale = fileName.split('.').first;
      if (localeCodes.contains(locale)) {
        final outFile = File(resolvePath('$translationsArbPath/app_$fileName'));
        if (!outFile.parent.existsSync()) {
          await outFile.parent.create(recursive: true);
        }
        await outFile.writeAsBytes(file.content);
        logger.success('  Saved: ${outFile.path}');
      }
    }
  }
}
