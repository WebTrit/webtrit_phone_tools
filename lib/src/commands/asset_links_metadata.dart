import 'dart:convert';

class AssetlinksMetadata {
  AssetlinksMetadata({
    required this.teamId,
  });

  final String teamId;

  Map<String, dynamic> toJson() {
    return {
      'teamId': teamId,
    };
  }

  String toJsonString() {
    return (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(toJson()))).toString();
  }
}
