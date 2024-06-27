import 'dart:convert';
import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/utils/password_generator.dart';

const _storeFileNameJKS = 'upload-keystore.jks';
const _storeFileNameP12 = 'upload-keystore.p12';

class KeystoreMetadata {
  KeystoreMetadata({
    required this.bundleId,
    required this.keyAlias,
    required this.keyPassword,
    required this.storeFileP12,
    required this.storeFileJKS,
    required this.storePassword,
    required this.dname,
  });

  factory KeystoreMetadata.fromJson(String jsonString) {
    final json = jsonDecode(jsonString) as Map;

    // TODO(Serdun): Remove this block after repo update
    // Migration 1: split storeFile to storeFileJKS and storeFileP12
    if (json.containsKey('storeFile')) {
      json['storeFileP12'] = json['storeFile'] ?? _storeFileNameP12;
      json['storeFileJKS'] = _storeFileNameJKS;
    }

    return KeystoreMetadata(
      bundleId: json['bundleId'] as String,
      keyAlias: json['keyAlias'] as String,
      keyPassword: json['keyPassword'] as String,
      storeFileP12: json['storeFileP12'] as String,
      storeFileJKS: json['storeFileJKS'] as String,
      storePassword: json['storePassword'] as String,
      dname: 'CN=$commonName, O=WebTrit, C=UA',
    );
  }

  factory KeystoreMetadata.conventional(String bundleId) {
    final password = PasswordGenerator.random(
      uppercase: true,
      numbers: true,
    );
    return KeystoreMetadata(
      bundleId: bundleId,
      keyAlias: 'upload',
      keyPassword: password,
      storeFileJKS: _storeFileNameJKS,
      storeFileP12: _storeFileNameP12,
      storePassword: password,
      dname: 'CN=$commonName, O=WebTrit, C=UA',
    );
  }

  String bundleId;
  String keyAlias;
  String keyPassword;
  String storeFileP12;
  String storeFileJKS;
  String storePassword;
  String dname;

  String toJsonString() {
    final metadataJson = {
      'bundleId': bundleId,
      'keyAlias': keyAlias,
      'keyPassword': keyPassword,
      'storeFile': storeFileP12,
      'storeFileJKS': storeFileJKS,
      'storePassword': storePassword,
    };
    return (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(metadataJson))).toString();
  }
}
