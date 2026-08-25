/// The App Store Connect key a keystore folder carries: `upload-store-connect-metadata.json`
/// names the issuer and the key, and the private key sits beside it as `AuthKey_<key id>.p8`.
class AppStoreConnectCredentials {
  const AppStoreConnectCredentials({
    required this.keyId,
    required this.issuerId,
    required this.privateKeyPath,
  });

  final String keyId;
  final String issuerId;
  final String privateKeyPath;
}
