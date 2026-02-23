class AssetlinksGenerateContext {
  const AssetlinksGenerateContext({
    required this.bundleId,
    required this.androidFingerprints,
    required this.outputPath,
    required this.teamId,
    required this.appendWellKnown,
  });

  final String bundleId;
  final List<String> androidFingerprints;
  final String outputPath;
  final String teamId;
  final bool appendWellKnown;
}
