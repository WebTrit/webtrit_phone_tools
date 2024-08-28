import 'dart:convert';

import 'package:webtrit_phone_tools/src/commands/constants.dart';
import 'package:webtrit_phone_tools/src/utils/password_generator.dart';

class KeystoreMetadata {
  KeystoreMetadata({
    required this.bundleId,
    required this.keyAlias,
    required this.keyPassword,
    required this.storeFile,
    required this.storePassword,
    required this.dname,
  });

  factory KeystoreMetadata.fromJson(String jsonString) {
    final json = jsonDecode(jsonString) as Map;

    return KeystoreMetadata(
      bundleId: json['bundleId'] as String,
      keyAlias: json['keyAlias'] as String,
      keyPassword: json['keyPassword'] as String,
      storeFile: json['storeFile'] as String,
      storePassword: json['storePassword'] as String,
      dname: 'CN=$commonName, O=WebTrit, C=UA',
    );
  }

  factory KeystoreMetadata.conventional(String bundleId, String storeFileName) {
    final password = PasswordGenerator.random(
      uppercase: true,
      numbers: true,
    );
    return KeystoreMetadata(
      bundleId: bundleId,
      keyAlias: 'upload',
      keyPassword: password,
      storeFile: storeFileName,
      storePassword: password,
      dname: 'CN=$commonName, O=WebTrit, C=UA',
    );
  }

  String bundleId;
  String keyAlias;
  String keyPassword;
  String storeFile;
  String storePassword;
  String dname;

  String toJsonString() {
    final metadataJson = {
      'bundleId': bundleId,
      'keyAlias': keyAlias,
      'keyPassword': keyPassword,
      'storeFile': storeFile,
      'storePassword': storePassword,
    };
    return (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(metadataJson))).toString();
  }
}
