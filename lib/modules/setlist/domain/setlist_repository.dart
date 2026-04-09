import '../../../core/error/result.dart';
import 'entities/setlist_document.dart';
import 'entities/setlist_key.dart';

abstract class SetlistRepository {
  Future<Result<SetlistDocument>> createSetlist({
    required String name,
    String? musicianProfileId,
    String? bandId,
  });

  Future<Result<SetlistDocument>> addSet({
    required String setlistId,
    required String title,
    String? duration,
    required int orderNumber,
  });

  Future<Result<SetlistDocument>> addItem({
    required String setId,
    required String artistName,
    required String songName,
    required SetlistKey key,
    required int orderNumber,
  });

  Future<Result<SetlistDocument>> getSetlistById(String setlistId);

  Future<Result<void>> deleteSetlist(String setlistId);

  Future<Result<List<int>>> downloadPdf(String setlistId);
}
