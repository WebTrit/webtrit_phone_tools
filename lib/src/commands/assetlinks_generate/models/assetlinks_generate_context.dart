class AssetlinksGenerateContext {
  const AssetlinksGenerateContext({
    required this.bundleId,
    required this.androidFingerprints,
    required this.outputPath,
    required this.teamId,
    required this.appendWellKnown,
    String? androidBundleId,
  }) : androidBundleId = androidBundleId ?? bundleId;

  final String bundleId;

  /// The package Android verifies against, which is not always the identifier
  /// Apple verifies against: two of the brands in production differ. Defaults
  /// to [bundleId] so a caller with one identifier keeps working.
  final String androidBundleId;
  final List<String> androidFingerprints;
  final String outputPath;
  final String teamId;
  final bool appendWellKnown;
}
