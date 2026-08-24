import 'dart:async';
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

  /// Writes the translations a brand ships, and only those.
  ///
  /// [chosen] is what the theme enables, straight from the build bundle. An
  /// empty list is not "none" - it is "whatever there is", which is what a brand
  /// that has never narrowed its languages means and what every build did before
  /// this was configurable.
  ///
  /// The list used to come from `localizely.yml`, a file of the translation
  /// service this product stopped using: a build whose checkout lacked it wrote
  /// no translations at all and said so only in a warning, so a brand shipped
  /// with the app's built-in strings and nothing said otherwise.
  Future<void> process({
    required String applicationId,
    required List<String> chosen,
    required String Function(String) resolvePath,
  }) async {
    final wanted = chosen.map((code) => code.trim().toLowerCase()).where((code) => code.isNotEmpty).toSet();

    logger.info(
      wanted.isEmpty
          ? 'Writing every language the service sends'
          : 'Writing the languages this brand enables: ${wanted.join(', ')}',
    );

    final zipFiles = await httpClient.getTranslationFiles(applicationId);
    final written = <String>{};

    for (final file in zipFiles) {
      final fileName = p.basename(file.name);

      if (fileName.isEmpty || fileName != file.name) {
        logger.detail('Skipping suspicious file path: ${file.name}');
        continue;
      }

      final locale = fileName.split('.').first;
      if (wanted.isNotEmpty && !wanted.contains(locale.toLowerCase())) continue;

      await _writeArbFile(resolvePath('$translationsArbPath/app_$fileName'), file.content as List<int>);
      written.add(locale.toLowerCase());
    }

    if (wanted.isEmpty) return;

    final missing = wanted.difference(written);
    if (missing.isNotEmpty) {
      // The theme names a language the catalog has nothing for. Saying so is the
      // point: the alternative is a brand shipping without a language it asked
      // for and nobody knowing until somebody opens the app in it.
      logger.warn('The service sent nothing for: ${missing.join(', ')}');
    }

    await _removeUnchosen(wanted, resolvePath);
  }

  /// Deletes the translations this brand did not choose.
  ///
  /// They are checked into the app's repository, so a build that only writes
  /// leaves them all in place - and `gen-l10n` builds the app's list of
  /// languages from whatever is in the folder. Without this the brand offers
  /// every language the app has ever had, whatever it chose.
  Future<void> _removeUnchosen(Set<String> wanted, String Function(String) resolvePath) async {
    final directory = Directory(resolvePath(translationsArbPath));
    if (!directory.existsSync()) return;

    for (final entry in directory.listSync()) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      final match = RegExp(r'^app_([A-Za-z_]+)\.arb$').firstMatch(name);
      if (match == null) continue;

      final locale = match.group(1)!.toLowerCase();
      if (wanted.contains(locale)) continue;

      await entry.delete();
      logger.detail('Removed $name: this brand does not ship that language');
    }
  }

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
