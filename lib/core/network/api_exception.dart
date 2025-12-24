import '../error/app_error.dart';

class ApiException implements Exception {
  final AppError error;

  ApiException(this.error);

  @override
  String toString() => 'ApiException(${error.code}): ${error.message}';
}
