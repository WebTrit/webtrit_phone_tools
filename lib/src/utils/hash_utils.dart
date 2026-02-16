/// A utility class for generating fast, non-cryptographic hash strings.
abstract final class HashUtils {
  /// Generates a short hex string from the [input] using the DJB2 algorithm.
  ///
  /// The result is a 32-bit unsigned integer represented as a hexadecimal string.
  /// This is suitable for filename versioning, cache keys, or unique identifiers
  /// where cryptographic security is not required.
  ///
  /// Example:
  /// ```dart
  /// final id = HashUtils.generateShort('[https://example.com/image.png](https://example.com/image.png)');
  /// // returns a string like '7c89f2a1'
  /// ```
  static String generateShort(String input) {
    var hash = 5381;

    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
    }

    return hash.toUnsigned(32).toRadixString(16);
  }
}
