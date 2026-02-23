class KeystoreCommitContext {
  const KeystoreCommitContext({
    required this.workingDirectoryPath,
    required this.bundleId,
    required this.appendDirectory,
    required this.executePush,
  });

  final String workingDirectoryPath;
  final String bundleId;
  final bool appendDirectory;
  final bool executePush;
}
