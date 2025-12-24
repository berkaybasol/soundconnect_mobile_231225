class AppError {
  final String code;
  final String message;
  final List<String> details;

  const AppError({
    required this.code,
    required this.message,
    this.details = const [],
  });
}
