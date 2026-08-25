class AppStoreCertificate {
  const AppStoreCertificate({
    required this.id,
    required this.content,
    required this.certificateType,
  });

  final String id;
  final String content;
  final String certificateType;
}

class AppStoreProfile {
  const AppStoreProfile({
    required this.id,
    required this.name,
    required this.state,
    required this.content,
    required this.bundleIdResourceId,
    required this.certificateIds,
  });

  final String id;
  final String name;
  final String state;
  final String content;
  final String bundleIdResourceId;
  final List<String> certificateIds;
}

class AppStoreConnectException implements Exception {
  const AppStoreConnectException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'App Store Connect responded $statusCode: $message';
}
