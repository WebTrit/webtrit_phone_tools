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
const _apiKeyPrefix = 'wtc_';
const _defaultOutputPath = 'lib/l10n/arb';

const _paramDirectory = '<directory>';

/// Pulls the global translation catalog into the phone repository - what
/// `l10n:fetch` did in the Localizely era. The catalog is the source of
/// truth; the ARB files this writes are its export, so existing files are
/// overwritten rather than merged. All locales or nothing: a partial set
/// would ship English fallbacks silently.
class TranslationsFetchCommand extends Command<int> {
  TranslationsFetchCommand({
    required Logger logger,
    required HttpClient httpClient,
  })  : _logger = logger,
        _httpClient = httpClient {
    argParser
      ..addOption(
        _argToken,
        help: 'JWT token for the configurator API; '
            'falls back to the $_tokenEnvironmentVariable environment variable.',
      )
      ..addOption(
        _argOutput,
        help:
            'Directory the ARB files are written to, relative to $_paramDirectory.',
        defaultsTo: _defaultOutputPath,
      );
  }

  @override
  String get name => 'configurator-translations-fetch';

  @override
  String get description => CommandHelpFormatter.formatDescription(
        title:
            'Fetch the translation catalog into the phone repository ARB files',
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
    final token = (argResults![_argToken] as String?) ??
        Platform.environment[_tokenEnvironmentVariable];
    if (token == null || token.isEmpty) {
      _logger.err(
          'No token: pass --$_argToken or set $_tokenEnvironmentVariable.');
      return ExitCode.usage.code;
    }

    final rest = argResults!.rest;
    if (rest.length > 1) {
      _logger.err('At most one $_paramDirectory argument is expected.');
      return ExitCode.usage.code;
    }
    final workingDirectoryPath =
        rest.isNotEmpty ? rest.single : Directory.current.path;
    final outputDirectoryPath =
        path.join(workingDirectoryPath, argResults![_argOutput] as String);

    try {
      // An administrator-minted API key (wtc_...) travels in its own header;
      // anything else is treated as a signed-in bearer token.
      final archive = await _httpClient.getCatalogTranslationFiles(
        headers: token.startsWith(_apiKeyPrefix)
            ? {'X-Api-Key': token}
            : {'Authorization': 'Bearer $token'},
      );

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
        arbByLocale[locale] = jsonDecode(utf8.decode(file.content as List<int>))
            as Map<String, dynamic>;
      }

      if (arbByLocale.isEmpty) {
        _logger.err('The catalog returned no locales; nothing was written.');
        return ExitCode.software.code;
      }

      final outputDirectory = Directory(outputDirectoryPath);
      if (!outputDirectory.existsSync()) {
        await outputDirectory.create(recursive: true);
      }

      for (final entry in arbByLocale.entries) {
        final outFile =
            File(path.join(outputDirectoryPath, 'app_${entry.key}.arb'));
        await outFile.writeAsString(
            '${const JsonEncoder.withIndent('  ').convert(entry.value)}\n');
        final keys =
            entry.value.keys.where((key) => !key.startsWith('@')).length;
        _logger.success('  Saved: ${outFile.path} ($keys keys)');
      }

      _logger.success(
          'Fetched ${arbByLocale.length} locales from the translation catalog.');
      return ExitCode.success.code;
    } on Exception catch (e) {
      _logger.err('$e');
      return ExitCode.software.code;
    }
  }
}
