import 'dart:convert';

class AssetLinks {
  AssetLinks({
    required this.packageName,
    required this.sha256CertFingerprints,
  });

  final String packageName;
  final List<String> sha256CertFingerprints;

  Map<String, dynamic> toJson() {
    return {
      'relation': ['delegate_permission/common.handle_all_urls'],
      'target': {
        'package_name': packageName,
        'sha256_cert_fingerprints': sha256CertFingerprints,
      },
    };
  }

  String toJsonString() {
    return (StringBuffer()..writeln(const JsonEncoder.withIndent('  ').convert(toJson()))).toString();
  }
}
