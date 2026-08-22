import 'dart:io';

const parameterIndent = '  ';
const parameterDelimiter = ' - ';

// Environment APIs
//
// The API every command talks to, version segment included. This is the new
// configurator backend (Cloud Run, its own sign-in and database); the token in
// CONFIGURATOR_TOKEN must be one that backend issued. Point a run at another
// deployment with WEBTRIT_CONFIGURATOR_API_URL.
const configuratorProdApiUrl = 'https://configurator-backend-v2-wsvbtokyoq-ew.a.run.app/v1';

/// Name of the variable that points a run at a deployment other than
/// [configuratorProdApiUrl].
const configuratorApiUrlVariable = 'WEBTRIT_CONFIGURATOR_API_URL';

/// The API address a run talks to, taken from [environment] and defaulting to
/// the process environment.
String resolveConfiguratorApiUrl([Map<String, String>? environment]) {
  final overrides = environment ?? Platform.environment;
  return overrides[configuratorApiUrlVariable] ?? configuratorProdApiUrl;
}

final configuratorApiUrl = resolveConfiguratorApiUrl();
