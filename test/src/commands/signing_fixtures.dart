import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

const testKeyId = 'ABCDE12345';
const testIssuerId = '11111111-2222-3333-4444-555555555555';
const testBundleId = 'com.example.app';
const testTeamId = 'TEAM123456';

/// Writes the two files every App Store Connect command reads: the metadata
/// naming the key, and a real P-256 key for it, so the token is genuinely signed.
void writeSigningFixtures(String directoryPath) {
  final metadata = {
    'bundleId': testBundleId,
    'issuer-id': testIssuerId,
    'key_id': testKeyId,
    'code-signing-identity': '',
    'team-id': '',
  };
  File(path.join(directoryPath, 'upload-store-connect-metadata.json'))
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(metadata));

  final privateKeyPath = path.join(directoryPath, 'AuthKey_$testKeyId.p8');
  final generated = Process.runSync(
    'openssl',
    ['genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256', '-out', privateKeyPath],
    runInShell: true,
  );
  if (generated.exitCode != 0) {
    throw StateError('Could not generate a test key: ${generated.stderr}');
  }
}

/// A provisioning profile shaped like the ones Apple signs: a plist wrapped in
/// bytes the parser has to look past.
List<int> provisioningProfileBytes({String teamId = testTeamId}) {
  final plist = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<plist version="1.0">',
    '<dict>',
    '  <key>Name</key>',
    '  <string>Provision</string>',
    '  <key>TeamIdentifier</key>',
    '  <array>',
    '    <string>$teamId</string>',
    '  </array>',
    '</dict>',
    '</plist>',
  ].join('\n');
  return [...utf8.encode('signature'), ...utf8.encode(plist), ...utf8.encode('trailer')];
}
