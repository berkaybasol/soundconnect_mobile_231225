/// Matches the server's Java @Size limit: UTF-16 units, not grapheme clusters.
abstract final class CommentText {
  static const maxLength = 500;
  static int length(String text) => text.trim().length;
  static bool isValid(String text) =>
      text.trim().isNotEmpty && length(text) <= maxLength;
}
