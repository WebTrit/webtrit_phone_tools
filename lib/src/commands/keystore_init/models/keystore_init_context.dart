class KeystoreInitContext {
  const KeystoreInitContext({
    required this.workingDirectoryPath,
    required this.applicationId,
    required this.authHeader,
  });

  final String workingDirectoryPath;
  final String applicationId;
  final Map<String, String> authHeader;
}
