class ArbMergeUtil {
  /// Merges a downloaded ARB into the one the checkout carries.
  ///
  /// What a message SAYS comes from the translation service. What a message
  /// TAKES - its placeholders, their types and, decisively, their order -
  /// belongs to the app: `gen-l10n` turns that order into the order of the
  /// generated method's arguments, so a reordering silently rewrites a call
  /// signature. The service stores placeholders in a map and hands them back
  /// alphabetically, which is a different order than the app declared, and
  /// letting that win renames nothing and breaks everything.
  ///
  /// So the metadata entries - the `@`-prefixed ones - are taken from the local
  /// file whenever it has them, and from the download only for a message the
  /// checkout has never seen. Values are taken from the download, which is the
  /// point of downloading.
  ///
  /// When the two placeholder types differ this shows up as a compile error, as
  /// it did for the WebView error message. When they are both strings it does
  /// not: the arguments simply swap places, and a person reads someone else's
  /// error code where a description should be.
  static Map<String, dynamic> mergeArb(Map<String, dynamic> local, Map<String, dynamic> downloaded) {
    final merged = <String, dynamic>{...local};
    for (final entry in downloaded.entries) {
      final isMetadata = entry.key.startsWith('@') && !entry.key.startsWith('@@');
      if (isMetadata && local.containsKey(entry.key)) continue;
      merged[entry.key] = entry.value;
    }
    return merged;
  }
}
