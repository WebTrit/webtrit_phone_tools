class ProvisionCreateContext {
  const ProvisionCreateContext({
    required this.workingDirectoryPath,
    required this.certificatePath,
    required this.profilePath,
    required this.metadataPath,
    required this.profileName,
    required this.profileType,
    required this.bundleId,
    required this.replaceExisting,
    required this.issuerId,
    required this.keyId,
    required this.authKeyPath,
  });

  final String workingDirectoryPath;
  final String certificatePath;
  final String profilePath;
  final String metadataPath;
  final String profileName;
  final String profileType;
  final String bundleId;
  final bool replaceExisting;
  final String issuerId;
  final String keyId;
  final String authKeyPath;
}
