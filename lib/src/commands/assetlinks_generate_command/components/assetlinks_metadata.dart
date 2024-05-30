import 'dart:convert';

class AssetlinksMetadata {
  AssetlinksMetadata({required this.teamId});

  factory AssetlinksMetadata.fromJson(Map<String, dynamic> json) {
    return AssetlinksMetadata(teamId: json['teamId'] as String);
  }

  factory AssetlinksMetadata.fromJsonString(String jsonString) {
    return AssetlinksMetadata.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  final String teamId;

  Map<String, dynamic> toJson() {
    return {'teamId': teamId};
  }

  String toJsonString() {
    return (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(toJson()))).toString();
  }
}
