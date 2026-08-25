class ProvisionConflictException implements Exception {
  const ProvisionConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}
