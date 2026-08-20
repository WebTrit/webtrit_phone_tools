import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../constants/constants.dart';
import '../utils/utils.dart';
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
    final localeCodes = _collectLocaleCodes(resolvePath);

    if (localeCodes.isEmpty) {
      logger.warn(
        'No app_*.arb files found under $translationsArbPath; accepting all downloaded locales.',
      );
    } else {
      logger.info('Downloading translations for: ${localeCodes.join(', ')}');
    }

    final zipFiles = await httpClient.getTranslationFiles(applicationId);

    for (final file in zipFiles) {
      final fileName = p.basename(file.name);

      if (fileName.isEmpty || fileName != file.name) {
        logger.detail('Skipping suspicious file path: ${file.name}');
        continue;
      }

      final locale = fileName.split('.').first;
      if (localeCodes.isEmpty || localeCodes.contains(_normalizeLocale(locale))) {
        await _writeArbFile(resolvePath('$translationsArbPath/app_$fileName'), file.content as List<int>);
      }
    }
  }

  /// Locale codes derived from the app_<locale>.arb files already present in
  /// the working directory; they act as a whitelist over the downloaded ZIP.
  Set<String> _collectLocaleCodes(String Function(String) resolvePath) {
    final arbDirectory = Directory(resolvePath(translationsArbPath));
    if (!arbDirectory.existsSync()) {
      return const {};
    }

    final localeCodes = arbDirectory
        .listSync()
        .whereType<File>()
        .map((file) => p.basename(file.path))
        .where((name) => name.startsWith('app_') && name.endsWith('.arb'))
        .map((name) => name.substring('app_'.length, name.length - '.arb'.length))
        .where((locale) => locale.isNotEmpty)
        .map(_normalizeLocale)
        .toSet();

    return SplayTreeSet.of(localeCodes);
  }

  /// ARB filenames spell region subtags with an underscore (app_pt_BR.arb)
  /// while ZIP entries may use the hyphenated form (pt-BR.arb).
  String _normalizeLocale(String locale) => locale.toLowerCase().replaceAll('_', '-');

  Future<void> _writeArbFile(String outPath, List<int> downloadedBytes) async {
    final outFile = File(outPath);
    if (!outFile.parent.existsSync()) {
      await outFile.parent.create(recursive: true);
    }

    final downloaded = jsonDecode(utf8.decode(downloadedBytes)) as Map<String, dynamic>;

    if (!outFile.existsSync()) {
      await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(downloaded));
      logger.success('  Saved: ${outFile.path}');
      return;
    }

    try {
      final local = jsonDecode(await outFile.readAsString()) as Map<String, dynamic>;
      final merged = ArbMergeUtil.mergeArb(local, downloaded);
      await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(merged));
      logger.success('  Merged: ${outFile.path}');
    } on FormatException {
      logger.warn('  Existing file has invalid JSON, overwriting: ${outFile.path}');
      await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(downloaded));
    }
  }
}
