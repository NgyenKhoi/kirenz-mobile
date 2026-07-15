enum ApiFailureKind { transport, server, application, parsing }

ApiFailureKind apiFailureKindForResponse({
  required bool hasResponse,
  int? statusCode,
}) {
  if (!hasResponse) return ApiFailureKind.transport;
  if ((statusCode ?? 0) >= 500) return ApiFailureKind.server;
  return ApiFailureKind.application;
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
    this.kind = ApiFailureKind.application,
  });

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;
  final ApiFailureKind kind;

  @override
  String toString() => message;
}
