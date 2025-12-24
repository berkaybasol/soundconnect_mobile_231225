import 'app_error.dart';

class Result<T> {
  final T? data;
  final AppError? error;

  const Result.success(this.data) : error = null;
  const Result.failure(this.error) : data = null;

  bool get isSuccess => data != null;
}
