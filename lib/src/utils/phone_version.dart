import 'dart:io';

import 'package:yaml/yaml.dart';

/// The phone version a build is for, read from the checkout the command runs
/// in (the custom `app_version` field of the root pubspec; the standard
/// `version` field deliberately stays 0.0.0 there).
///
/// Sent to the configurator backend as `X-Phone-Version`: the data is the same
/// for every era, but the backend records who wrote what, and the day a schema
/// reshape needs serving differently per era this header is the switch. A
/// checkout without the field (or no checkout at all) simply sends nothing.
String? readPhoneVersion([String? directory]) {
  try {
    final file = File('${directory ?? Directory.current.path}/pubspec.yaml');
    if (!file.existsSync()) return null;
    final pubspec = loadYaml(file.readAsStringSync());
    final raw = (pubspec as Map)['app_version']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw.split('+').first;
  } catch (_) {
    return null;
  }
}
