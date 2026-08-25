import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

const _pemPrefix = '-----BEGIN';
const _plistStart = '<?xml';
const _plistEnd = '</plist>';

final _teamIdentifierPattern = RegExp(
  r'<key>TeamIdentifier</key>\s*<array>\s*<string>([^<]+)</string>',
);

class ProfileProcessor {
  const ProfileProcessor({required this.logger});

  final Logger logger;

  /// The certificate in [certificatePath] encoded the way App Store Connect
  /// returns it, so a local file can be matched against the account's list.
  String readCertificateContent(String certificatePath) {
    final bytes = File(certificatePath).readAsBytesSync();
    final text = latin1.decode(bytes);
    if (!text.startsWith(_pemPrefix)) {
      return base64.encode(bytes);
    }

    final body = text.split('\n').where((line) => !line.startsWith(_pemPrefix) && !line.startsWith('-----END'));
    return body.join().replaceAll(RegExp(r'\s'), '');
  }

  void writeProfile({
    required String profilePath,
    required String profileContent,
  }) {
    logger.info('Writing provisioning profile to: ${path.basename(profilePath)}');
    File(profilePath).writeAsBytesSync(base64.decode(profileContent), flush: true);
  }

  /// The team the profile belongs to, read from the plist Apple signs into the
  /// profile. Returns `null` when the profile carries no team identifier.
  String? extractTeamId(String profilePath) {
    final text = latin1.decode(File(profilePath).readAsBytesSync());
    final start = text.indexOf(_plistStart);
    final end = text.indexOf(_plistEnd);
    if (start == -1 || end == -1 || end < start) {
      logger.err('No property list found inside: ${path.basename(profilePath)}');
      return null;
    }

    final match = _teamIdentifierPattern.firstMatch(text.substring(start, end + _plistEnd.length));
    if (match == null) {
      logger.err('No team identifier found inside: ${path.basename(profilePath)}');
      return null;
    }
    return match.group(1);
  }
}
