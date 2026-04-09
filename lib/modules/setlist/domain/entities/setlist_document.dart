import 'setlist_set.dart';

class SetlistDocument {
  final String id;
  final String name;
  final String? musicianProfileId;
  final String? bandId;
  final List<SetlistSet> sets;

  const SetlistDocument({
    required this.id,
    required this.name,
    required this.musicianProfileId,
    required this.bandId,
    required this.sets,
  });
}
