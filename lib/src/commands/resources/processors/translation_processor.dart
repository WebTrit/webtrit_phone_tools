import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:yaml/yaml.dart';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
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

    final config = loadYaml(await configFile.readAsString());
    final localeCodes = (config['download']['files'] as List).map((e) => e['locale_code']).toSet();

    logger.info('Downloading translations for: ${localeCodes.join(', ')}');
    final zipFiles = await httpClient.getTranslationFiles(applicationId);

    for (final file in zipFiles) {
      final locale = file.name.split('.').first;
      if (localeCodes.contains(locale)) {
        final outFile = File(resolvePath('$translationsArbPath/app_${file.name}'));
        if (!outFile.parent.existsSync()) {
          await outFile.parent.create(recursive: true);
        }
        await outFile.writeAsBytes(file.content);
        logger.success('  Saved: ${outFile.path}');
      }
    }
  }
}
