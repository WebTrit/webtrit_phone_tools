// ignore_for_file: all

class StringifyAssets {
  static const String appleAssetLinksTemplate = "{\n  \"applinks\": {\n    \"details\": [\n      {\n        \"appID\": \"{{ appID }}\",\n        \"paths\": [ \"*\" ]\n      }\n    ]\n  }\n}\n";
  static const String googleAssetLinksTemplate = "{\n  \"relation\": [ \"delegate_permission/common.handle_all_urls\" ],\n  \"target\": {\n    \"package_name\": \"{{ package_name }}\",\n    \"sha256_cert_fingerprints\": {{ sha256_cert_fingerprints }}\n  }\n}\n";
  static const String uploadStoreConnectMetadata = "{\n  \"bundleId\": \"{{ BUNDLE_ID }}\",\n  \"issuer-id\": \"\",\n  \"key_id\": \"\",\n  \"code-signing-identity\": \"\",\n  \"team-id\": \"\"\n}\n";
}
