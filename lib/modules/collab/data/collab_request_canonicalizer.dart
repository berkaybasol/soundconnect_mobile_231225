import '../domain/collab_commands.dart';

String? canonicalCollabOptionalText(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String canonicalCollabPhone(String value) {
  final stripped = value.trim();
  final allowedCharacters = RegExp(r'^[+0-9() .-]+$').hasMatch(stripped);
  final plusCount = '+'.allMatches(stripped).length;
  final validPlus =
      plusCount == 0 || (plusCount == 1 && stripped.startsWith('+'));
  if (!allowedCharacters || !validPlus) return stripped;
  final digits = stripped.replaceAll(RegExp(r'\D'), '');
  return stripped.startsWith('+') ? '+$digits' : digits;
}

List<String> canonicalCollabGenres(Iterable<String> values) {
  final normalized =
      values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: true)
        ..sort((left, right) {
          final folded = left.toLowerCase().compareTo(right.toLowerCase());
          return folded != 0 ? folded : left.compareTo(right);
        });
  final seen = <String>{};
  return List<String>.unmodifiable(
    normalized.where((value) => seen.add(value.toLowerCase())),
  );
}

CollabListingInput canonicalCollabListingInput(CollabListingInput input) {
  final feeAmountMinor = input.feeAmountMinor;
  final normalizedCurrency = canonicalCollabOptionalText(
    input.currency,
  )?.toUpperCase();
  return CollabListingInput(
    publisherActorId: input.publisherActorId.trim(),
    cadence: input.cadence,
    wantedType: input.wantedType,
    instrumentId: canonicalCollabOptionalText(input.instrumentId),
    branch: input.branch,
    customSpecialty: canonicalCollabOptionalText(input.customSpecialty),
    title: input.title.trim(),
    description: input.description.trim(),
    cityId: input.cityId.trim(),
    genres: canonicalCollabGenres(input.genres),
    scheduledAt: input.scheduledAt?.toUtc(),
    feeAmountMinor: feeAmountMinor,
    currency: feeAmountMinor == null
        ? normalizedCurrency
        : normalizedCurrency ?? 'TRY',
  );
}

CollabApplicationInput canonicalCollabApplicationInput(
  CollabApplicationInput input,
) => CollabApplicationInput(
  applicantActorId: input.applicantActorId.trim(),
  phone: canonicalCollabPhone(input.phone),
  message: canonicalCollabOptionalText(input.message) ?? '',
);

CollabReportInput canonicalCollabReportInput(CollabReportInput input) =>
    CollabReportInput(
      reason: input.reason,
      details: canonicalCollabOptionalText(input.details),
    );

CollabReviewInput canonicalCollabReviewInput(CollabReviewInput input) =>
    CollabReviewInput(
      rating: input.rating,
      comment: canonicalCollabOptionalText(input.comment),
    );
