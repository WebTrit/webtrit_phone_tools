class KeystoreGenerateContext {
  const KeystoreGenerateContext({
    required this.workingDirectoryPath,
    required this.bundleId,
    required this.createParentDirectories,
    required this.appendDirectory,
  });

  final String workingDirectoryPath;
  final String bundleId;
  final bool createParentDirectories;
  final bool appendDirectory;
}
