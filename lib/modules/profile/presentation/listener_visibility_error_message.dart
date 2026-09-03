import '../../../core/error/app_error.dart';

const _visibilityRateLimitFallback =
    'Görünürlük ayarını çok sık değiştirdin. Lütfen kısa bir süre sonra tekrar dene.';
const _visibilityUpdateFallback = 'Profil görünürlüğü güncellenemedi.';

/// Resolves the user-facing message for a listener visibility mutation.
///
/// The current [AppError] transport does not expose response headers, so a
/// `Retry-After` value cannot be rendered here without widening the shared
/// networking contract. The backend's localized message is authoritative;
/// the local text is only a defensive fallback for empty 1306/429 responses.
String listenerVisibilityErrorMessage(AppError? error) {
  final message = error?.message.trim() ?? '';
  final code = error?.code.trim().toUpperCase() ?? '';
  // A bodyless 429 is mapped by Dio to a technical exception string. Keep
  // that transport detail out of the UI. Contracted backend errors use 1306
  // and carry the localized guidance instead.
  if (code == '429') return _visibilityRateLimitFallback;
  if (code == '1306') {
    return message.isEmpty ? _visibilityRateLimitFallback : message;
  }
  if (message.isNotEmpty) return message;
  return _visibilityUpdateFallback;
}
