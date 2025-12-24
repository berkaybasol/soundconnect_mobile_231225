class BaseResponse<T> {
  final bool? success;
  final String? message;
  final int? code;
  final T? data;

  const BaseResponse({
    required this.success,
    required this.message,
    required this.code,
    required this.data,
  });

  factory BaseResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json)? decoder,
  ) {
    final Object? rawData = json['data'];
    final T? parsedData =
        decoder != null ? decoder(rawData) : rawData as T?;

    return BaseResponse<T>(
      success: json['success'] as bool?,
      message: json['message'] as String?,
      code: (json['code'] as num?)?.toInt(),
      data: parsedData,
    );
  }
}
