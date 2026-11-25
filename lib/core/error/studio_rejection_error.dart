import 'app_error.dart';

/// Applicant-visible fields from a verified studio sign-in, held in memory.
class StudioRejectionError extends AppError {
  const StudioRejectionError({
    required super.code,
    this.businessName,
    this.rejectionReason,
  }) : super(message: 'Stüdyo başvurun reddedildi.');

  final String? businessName;
  final String? rejectionReason;

  factory StudioRejectionError.fromResponse(Map<String, dynamic> payload) {
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : null;
    return StudioRejectionError(
      code: '1112',
      businessName: text(payload['businessName']),
      rejectionReason: text(payload['rejectionReason']),
    );
  }

  factory StudioRejectionError.forLogin(AppError error) => StudioRejectionError(
    code: 'auth_studio_application_rejected',
    businessName: error is StudioRejectionError ? error.businessName : null,
    rejectionReason: error is StudioRejectionError
        ? error.rejectionReason
        : null,
  );
}
