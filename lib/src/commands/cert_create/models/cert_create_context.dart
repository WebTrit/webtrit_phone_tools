class CertCreateContext {
  const CertCreateContext({
    required this.workingDirectoryPath,
    required this.certificateSigningRequestPath,
    required this.certificatePath,
    required this.metadataPath,
    required this.certificateType,
    required this.issuerId,
    required this.keyId,
    required this.authKeyPath,
  });

  final String workingDirectoryPath;
  final String certificateSigningRequestPath;
  final String certificatePath;
  final String metadataPath;
  final String certificateType;
  final String issuerId;
  final String keyId;
  final String authKeyPath;
}
