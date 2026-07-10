class ApiResponse<T> {
  const ApiResponse({required this.success, this.message, this.data});

  final bool success;
  final String? message;
  final T? data;

  static ApiResponse<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Object? value) parseData,
  ) {
    return ApiResponse<T>(
      success: json['success'] == true,
      message: json['message']?.toString(),
      data: json.containsKey('data') ? parseData(json['data']) : null,
    );
  }
}
