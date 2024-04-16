import 'dart:convert';

extension StringExtensions on String {
  Map<String, dynamic> toMap() {
    try {
      return jsonDecode(this) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FormatException('Failed to convert string to map: $e');
    }
  }
}
