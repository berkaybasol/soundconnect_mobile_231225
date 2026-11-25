bool isValidAdminDecisionReason(String note) {
  final length = note.trim().runes.length;
  return length >= 5 && length <= 500;
}
