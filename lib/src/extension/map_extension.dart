import 'dart:convert';

extension MapExtension on Map<String, dynamic> {
  String toStringifyJson() {
    final jsonEncoder = const JsonEncoder.withIndent('  ').convert(this);
    return (StringBuffer()..writeln(jsonEncoder)).toString();
  }
}
