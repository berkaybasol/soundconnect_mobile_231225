import '../../../core/error/result.dart';
import 'entities/musician_calendar.dart';

/// A side-effect-free settings read for consumers that already listen to
/// [MusicianCalendarRepository.changes] and must distinguish real invalidations.
abstract interface class MusicianCalendarSettingsReader {
  Future<Result<MusicianCalendarSettings>> readSettingsWithoutNotification();
}

abstract class MusicianCalendarRepository {
  Stream<void> get changes;
  void invalidate();
  Future<void> dispose();

  Future<Result<MusicianCalendarSettings>> getSettings();
  Future<Result<MusicianCalendarSettings>> updateSettings({
    required bool visible,
    required int version,
  });
  Future<Result<MusicianCalendarPage>> getCalendar({
    required String profileId,
    required DateTime startDate,
    required DateTime endDate,
    int page = 0,
    int size = 20,
  });
}
