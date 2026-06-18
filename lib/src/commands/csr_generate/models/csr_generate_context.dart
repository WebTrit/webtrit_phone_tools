class CsrGenerateContext {
  const CsrGenerateContext({
    required this.workingDirectoryPath,
    required this.email,
    required this.commonName,
    required this.keySize,
    required this.createParentDirectories,
  });

  final String workingDirectoryPath;
  final String email;
  final String commonName;
  final int keySize;
  final bool createParentDirectories;

  String get subject => '/emailAddress=$email/CN=$commonName';
}
