import 'dart:convert';

extension StringExtensions on String {
  Map<String, dynamic> toMap() {
    try {
      return jsonDecode(this) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FormatException('Failed to convert string to map: $e');
    }
  }

  /// Converts a hex string (e.g. #AABBCC, AABBCC, #FFAABBCC)
  /// to a 6-character hex string with hash (e.g. #AABBCC).
  /// Handles alpha channel stripping if present (8 chars).
  String toHex6WithHash() {
    final hex = replaceAll('#', '').toUpperCase();

    if (hex.length == 8) {
      return '#${hex.substring(2)}';
    }

    if (hex.length == 6) {
      return '#$hex';
    }

    throw FormatException('Invalid hex color string: "$this"');
  }
}
