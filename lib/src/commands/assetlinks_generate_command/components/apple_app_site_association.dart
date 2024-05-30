import 'dart:convert';

class AppleAppSiteAssociation {
  AppleAppSiteAssociation({
    required this.teamId,
    required this.bundleId,
  });

  final String teamId;
  final String bundleId;

  Map<String, dynamic> toJson() {
    return {
      'applinks': {
        'details': [
          {
            'appID': '$teamId.$bundleId',
            'paths': ['*'],
          }
        ],
      },
    };
  }

  String toJsonString() {
    return (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(toJson()))).toString();
  }
}
