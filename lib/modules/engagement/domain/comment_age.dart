/// Formats the elapsed age of a comment instant without applying a timezone
/// shift. [now] can be supplied for deterministic tests or a shared UI clock.
String formatCommentAge(DateTime? value, {DateTime? now}) {
  if (value == null) return '';
  final age = (now ?? DateTime.now()).difference(value);
  if (age.inMinutes < 1) return 'Az önce';
  if (age.inHours < 1) return '${age.inMinutes} dk önce';
  if (age.inDays < 1) return '${age.inHours} saat önce';
  return '${age.inDays} gün önce';
}
