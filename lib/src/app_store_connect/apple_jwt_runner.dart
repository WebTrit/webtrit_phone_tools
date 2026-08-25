import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'app_store_connect_credentials.dart';

const _derSequenceTag = 0x30;
const _derIntegerTag = 0x02;
const _coordinateLength = 32;
const _tokenLifetime = Duration(minutes: 20);

/// Signs the ES256 token App Store Connect accepts in place of an Apple ID.
///
/// `openssl dgst -sign` returns an ECDSA signature wrapped in DER, while JWS
/// carries the raw `r || s` pair, so the DER structure is unwrapped here.
class AppleJwtRunner {
  const AppleJwtRunner({required this.logger});

  final Logger logger;

  /// A bearer token valid for [_tokenLifetime], or `null` when the key could
  /// not be read or the signature could not be produced.
  String? issueToken({
    required AppStoreConnectCredentials credentials,
    DateTime? issuedAt,
  }) {
    final issuedAtSeconds = (issuedAt ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final header = <String, Object>{'alg': 'ES256', 'kid': credentials.keyId, 'typ': 'JWT'};
    final payload = <String, Object>{
      'iss': credentials.issuerId,
      'iat': issuedAtSeconds,
      'exp': issuedAtSeconds + _tokenLifetime.inSeconds,
      'aud': 'appstoreconnect-v1',
    };

    final signingInput = '${_encodeSegment(header)}.${_encodeSegment(payload)}';
    final signature = _sign(privateKeyPath: credentials.privateKeyPath, signingInput: signingInput);
    if (signature == null) {
      return null;
    }

    return '$signingInput.${_encodeBytes(signature)}';
  }

  Uint8List? _sign({required String privateKeyPath, required String signingInput}) {
    final workDirectory = Directory.systemTemp.createTempSync('apple_jwt');
    try {
      final signingInputPath = path.join(workDirectory.path, 'signing_input');
      final signaturePath = path.join(workDirectory.path, 'signature.der');
      File(signingInputPath).writeAsStringSync(signingInput, flush: true);

      final result = Process.runSync(
        'openssl',
        ['dgst', '-sha256', '-sign', privateKeyPath, '-out', signaturePath, signingInputPath],
        runInShell: true,
      );
      if (result.exitCode != 0) {
        logger.err('Failed to sign the App Store Connect token: ${result.stderr}');
        return null;
      }

      final signature = _derToJose(File(signaturePath).readAsBytesSync());
      if (signature == null) {
        logger.err('The signature openssl produced is not a well-formed ECDSA signature.');
      }
      return signature;
    } finally {
      workDirectory.deleteSync(recursive: true);
    }
  }

  Uint8List? _derToJose(Uint8List der) {
    var offset = 0;
    if (offset >= der.length || der[offset++] != _derSequenceTag) {
      return null;
    }
    final sequence = _readLength(der, offset);
    if (sequence == null) {
      return null;
    }

    final (_, integersOffset) = sequence;
    final rField = _readInteger(der, integersOffset);
    if (rField == null) {
      return null;
    }

    final (r, sOffset) = rField;
    final sField = _readInteger(der, sOffset);
    if (sField == null) {
      return null;
    }

    final (s, _) = sField;
    if (r.length > _coordinateLength || s.length > _coordinateLength) {
      return null;
    }

    return Uint8List(_coordinateLength * 2)
      ..setRange(_coordinateLength - r.length, _coordinateLength, r)
      ..setRange(_coordinateLength * 2 - s.length, _coordinateLength * 2, s);
  }

  (int, int)? _readLength(Uint8List der, int offset) {
    var cursor = offset;
    if (cursor >= der.length) {
      return null;
    }

    final marker = der[cursor++];
    if (marker & 0x80 == 0) {
      return (marker, cursor);
    }

    final byteCount = marker & 0x7f;
    if (byteCount == 0 || byteCount > 4 || cursor + byteCount > der.length) {
      return null;
    }

    var length = 0;
    for (var index = 0; index < byteCount; index++) {
      length = (length << 8) | der[cursor++];
    }
    return (length, cursor);
  }

  (Uint8List, int)? _readInteger(Uint8List der, int offset) {
    var cursor = offset;
    if (cursor >= der.length || der[cursor++] != _derIntegerTag) {
      return null;
    }

    final header = _readLength(der, cursor);
    if (header == null) {
      return null;
    }

    final (length, valueOffset) = header;
    if (length == 0 || valueOffset + length > der.length) {
      return null;
    }

    var start = valueOffset;
    var remaining = length;
    while (remaining > 1 && der[start] == 0x00) {
      start++;
      remaining--;
    }
    return (Uint8List.sublistView(der, start, start + remaining), valueOffset + length);
  }

  String _encodeSegment(Map<String, Object> claims) => _encodeBytes(utf8.encode(jsonEncode(claims)));

  String _encodeBytes(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
}
