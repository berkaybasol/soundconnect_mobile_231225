import '../../../../core/error/app_error.dart';

const String collabStaleUpdateCode = '9317';
const String collabListingNotFoundCode = '9300';

bool isCollabStaleUpdate(AppError? error) {
  final code = error?.code.trim().toUpperCase() ?? '';
  return code == collabStaleUpdateCode || code == 'COLLAB_STALE_UPDATE';
}

bool isCollabListingNotFound(AppError? error) {
  final code = error?.code.trim().toUpperCase() ?? '';
  return code == collabListingNotFoundCode || code == 'COLLAB_NOT_FOUND';
}

AppError collabPreservedConflictError(AppError conflict) => AppError(
  code: conflict.code,
  message:
      '${conflict.message} İlan başka bir cihazda değişti. Bu cihazdaki form '
      'değişikliklerin korundu ve sunucudaki güncel sürüm alındı. Devam '
      'etmeden önce hangi sürümü kullanacağını seç.',
  details: conflict.details,
);

AppError collabDeletedConflictError(AppError conflict) => AppError(
  code: conflict.code,
  message:
      '${conflict.message} İlan diğer cihazda silinmiş. Bu cihazdaki form '
      'değişikliklerin korundu; istersen kopyalayabilirsin.',
  details: conflict.details,
);

AppError collabUnresolvedConflictError(AppError conflict) => AppError(
  code: conflict.code,
  message:
      '${conflict.message} Güncel sürüm alınamadı. Bu cihazdaki form '
      'değişikliklerin korundu. Devam etmek için bu ekrandan çıkıp ilanı '
      'yeniden aç.',
  details: conflict.details,
);
