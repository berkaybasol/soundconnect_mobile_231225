import 'listener_visibility_mode.dart';

/// Parses the optional visibility marker used by contextual identity DTOs.
///
/// Contextual endpoints may omit the field for legacy standard listeners. A
/// missing value therefore remains standard, while an unknown non-null value
/// fails closed to ghost so a forward-compatible server value can never make
/// restricted identity or actions visible. Strict wire boundaries may opt
/// into a [FormatException] instead.
ListenerVisibilityMode parseContextualListenerVisibilityMode(
  Object? value, {
  bool rejectUnknown = false,
}) {
  if (value is ListenerVisibilityMode) return value;
  try {
    return ListenerVisibilityMode.fromWire(value, allowMissingStandard: true);
  } on FormatException {
    if (rejectUnknown) rethrow;
    return ListenerVisibilityMode.ghost;
  }
}
