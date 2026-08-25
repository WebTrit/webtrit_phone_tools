import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'app_store_connect_constants.dart';
import 'app_store_connect_credentials.dart';

/// Locates the App Store Connect key a keystore folder holds, taking the issuer
/// and key ids from the metadata unless the caller overrides them.
class SigningCredentialsProcessor {
  const SigningCredentialsProcessor({required this.logger});

  final Logger logger;

  AppStoreConnectCredentials? resolve({
    required String directoryPath,
    required Map<String, dynamic> metadata,
    String issuerIdOverride = '',
    String keyIdOverride = '',
    String authKeyPathOverride = '',
  }) {
    final issuerId = issuerIdOverride.isNotEmpty ? issuerIdOverride : metadata[issuerIdMetadataKey] as String? ?? '';
    final keyId = keyIdOverride.isNotEmpty ? keyIdOverride : metadata[keyIdMetadataKey] as String? ?? '';

    if (issuerId.isEmpty || keyId.isEmpty) {
      logger.err(
        'Both "$issuerIdMetadataKey" and "$keyIdMetadataKey" must be known: fill them in the metadata or pass them '
        'as options.',
      );
      return null;
    }

    final privateKeyPath =
        authKeyPathOverride.isNotEmpty ? authKeyPathOverride : path.join(directoryPath, authKeyFileName(keyId));
    if (!File(privateKeyPath).existsSync()) {
      logger.err('App Store Connect private key not found: $privateKeyPath');
      return null;
    }

    return AppStoreConnectCredentials(keyId: keyId, issuerId: issuerId, privateKeyPath: privateKeyPath);
  }
}
