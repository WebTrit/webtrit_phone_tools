class CsrFinalizeContext {
  const CsrFinalizeContext({
    required this.certificatePath,
    required this.privateKeyPath,
    required this.pkcs12Path,
    required this.metadataPath,
    required this.password,
  });

  final String certificatePath;
  final String privateKeyPath;
  final String pkcs12Path;
  final String metadataPath;
  final String password;
}
