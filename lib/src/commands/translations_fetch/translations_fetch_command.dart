import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'package:webtrit_phone_tools/src/utils/utils.dart';

const _argToken = 'token';
const _argOutput = 'output';

const _tokenEnvironmentVariable = 'CONFIGURATOR_TOKEN';
const _defaultOutputPath = 'lib/l10n/arb';

const _paramDirectory = '<directory>';

/// Pulls the global translation catalog into the phone repository - what
/// `l10n:fetch` did in the Localizely era. The catalog is the source of
/// truth; the ARB files this writes are its export, so existing files are
/// overwritten rather than merged. All locales or nothing: a partial set
/// would ship English fallbacks silently.
class TranslationsFetchCommand extends Command<int> {
  TranslationsFetchCommand({required Logger logger, required HttpClient httpClient})
      : _logger = logger,
        _httpClient = httpClient {
    argParser
      ..addOption(
        _argToken,
        help: 'JWT token for the configurator API; '
            'falls back to the $_tokenEnvironmentVariable environment variable.',
      )
      ..addOption(
        _argOutput,
        help: 'Directory the ARB files are written to, relative to $_paramDirectory.',
        defaultsTo: _defaultOutputPath,
      );
  }

  @override
  String get name => 'configurator-translations-fetch';

  @override
  String get description => CommandHelpFormatter.formatDescription(
        title: 'Fetch the translation catalog into the phone repository ARB files',
        parameter: '$_paramDirectory (optional)',
        description: 'Phone repository root the files are written under.',
        note: 'Defaults to the current working directory if not provided.',
      );

  @override
  String get invocation => '${super.invocation} [$_paramDirectory]';

  final Logger _logger;
  final HttpClient _httpClient;

  @override
  Future<int> run() async {
    final token = (argResults![_argToken] as String?) ?? Platform.environment[_tokenEnvironmentVariable];
    if (token == null || token.isEmpty) {
      _logger.err('No token: pass --$_argToken or set $_tokenEnvironmentVariable.');
      return ExitCode.usage.code;
    }

    final rest = argResults!.rest;
    if (rest.length > 1) {
      _logger.err('At most one $_paramDirectory argument is expected.');
      return ExitCode.usage.code;
    }
    final workingDirectoryPath = rest.isNotEmpty ? rest.single : Directory.current.path;
    final outputDirectoryPath = path.join(workingDirectoryPath, argResults![_argOutput] as String);

    try {
      // An administrator-minted API key (wtc_...) travels in its own header;
      // anything else is treated as a signed-in bearer token.
      final archive = await _httpClient.getCatalogTranslationFiles(headers: credentialHeader(token));

      // Parse everything before writing anything: a half-written locale set
      // is worse than a failed run.
      final arbByLocale = <String, Map<String, dynamic>>{};
      for (final file in archive.files) {
        final fileName = path.basename(file.name);
        if (fileName != file.name || !fileName.endsWith('.arb')) {
          _logger.detail('Skipping unexpected archive entry: ${file.name}');
          continue;
        }
        final locale = fileName.substring(0, fileName.length - '.arb'.length);
        arbByLocale[locale] = jsonDecode(utf8.decode(file.content as List<int>)) as Map<String, dynamic>;
      }

      if (arbByLocale.isEmpty) {
        _logger.err('The catalog returned no locales; nothing was written.');
        return ExitCode.software.code;
      }

      final outputDirectory = Directory(outputDirectoryPath);
      if (!outputDirectory.existsSync()) {
        await outputDirectory.create(recursive: true);
      }

      final refusal = _wouldLose(outputDirectoryPath, arbByLocale);
      if (refusal != null) {
        _logger.err(refusal);
        return ExitCode.software.code;
      }

      var written = 0;
      for (final entry in arbByLocale.entries) {
        final outFile = File(path.join(outputDirectoryPath, 'app_${entry.key}.arb'));
        final keys = entry.value.keys.where((key) => !key.startsWith('@')).length;

        // Compared by CONTENT, not by text. A checkout's ARB files are not
        // shaped the way this renders them - hand edits and gen-l10n leave some
        // `@key` objects on one line and expand others - and the catalog orders
        // keys its own way. Rewriting a file whose meaning is unchanged would
        // bury a one-word correction under thousands of lines of reformatting,
        // every single time somebody pulls.
        if (outFile.existsSync() && _canonical(_parseOrNull(outFile)) == _canonical(entry.value)) {
          _logger.detail('  Unchanged: ${outFile.path} ($keys keys)');
          continue;
        }

        await outFile.writeAsString('${const JsonEncoder.withIndent('  ').convert(entry.value)}\n');
        written++;
        _logger.success('  Saved: ${outFile.path} ($keys keys)');
      }

      if (written == 0) {
        _logger.success('The catalog holds what this checkout already holds; nothing was rewritten.');
      } else {
        _logger.success('Fetched ${arbByLocale.length} locales from the translation catalog, $written rewritten.');
      }
      return ExitCode.success.code;
    } on Exception catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }
  }

  /// Why this export must not be adopted, or null when it is safe.
  ///
  /// The write below OVERWRITES each file; it does not merge, because the
  /// catalog owns the values. That makes it destructive whenever the catalog
  /// has not been synced since the last keys were added to the checkout: it
  /// would simply not carry them, and overwriting would drop them from every
  /// locale at once. The app calls those keys, so the loss surfaces later as
  /// `undefined_getter` on generated code, a long way from this command.
  ///
  /// So every locale the checkout already has must be present in the export and
  /// must still carry everything it carries now. No locale is treated as the
  /// template - which one that is belongs to the checkout, not here.
  String? _wouldLose(String outputDirectoryPath, Map<String, Map<String, dynamic>> arbByLocale) {
    final existing = Directory(outputDirectoryPath)
        .listSync()
        .whereType<File>()
        .where((file) => path.basename(file.path).startsWith('app_') && file.path.endsWith('.arb'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in existing) {
      final name = path.basename(file.path);
      final locale = name.substring('app_'.length, name.length - '.arb'.length);

      final exported = arbByLocale[locale];
      if (exported == null) {
        return 'The catalog export has no $locale, but this checkout does ($name). '
            'A partial set leaves some locales current and others frozen with nothing to say '
            'which is which, so nothing was written.';
      }

      final current = _parseOrNull(file);
      if (current == null) continue; // Unreadable already; overwriting can only help.

      final missing = current.keys.where((key) => !key.startsWith('@') && !exported.containsKey(key)).toList()..sort();
      if (missing.isEmpty) continue;

      final currentCount = current.keys.where((key) => !key.startsWith('@')).length;
      final exportedCount = exported.keys.where((key) => !key.startsWith('@')).length;
      final sample = missing.take(5).map((key) => '\n    $key').join();
      final more = missing.length > 5 ? '\n    ... and ${missing.length - 5} more' : '';
      return 'The catalog export is behind this checkout: for $locale it carries $exportedCount keys '
          'where $name has $currentCount, so adopting it would delete ${missing.length} of them.'
          '$sample$more\n'
          'Run the catalog sync against a ref that carries these keys, then fetch again. '
          'Nothing was written.';
    }
    return null;
  }

  Map<String, dynamic>? _parseOrNull(File file) {
    try {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } on Exception {
      return null;
    }
  }

  /// A form two ARB files compare by with order and whitespace removed, so only
  /// a difference in what a key MEANS counts as a change.
  String _canonical(Map<String, dynamic>? arb) {
    if (arb == null) return '';
    final keys = arb.keys.toList()..sort();
    return jsonEncode({for (final key in keys) key: arb[key]});
  }
}
