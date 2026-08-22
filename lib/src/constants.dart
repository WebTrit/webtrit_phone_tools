import 'dart:io';

const parameterIndent = '  ';
const parameterDelimiter = ' - ';

// Environment APIs
//
// The API every command talks to, version segment included. This is the new
// configurator backend (Cloud Run, its own sign-in and database); the token in
// CONFIGURATOR_TOKEN must be one that backend issued. Point a run at another
// deployment with WEBTRIT_CONFIGURATOR_API_URL.
const _configuratorProdApiUrl = 'https://configurator-backend-v2-wsvbtokyoq-ew.a.run.app/v1';
final configuratorApiUrl = Platform.environment['WEBTRIT_CONFIGURATOR_API_URL'] ?? _configuratorProdApiUrl;
