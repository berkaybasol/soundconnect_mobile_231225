import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../domain/collab_page.dart';
import '../../domain/collab_repository.dart';
import '../../domain/entities/collab_review.dart';
import 'collab_paged_cubit.dart';

class CollabActorReviewsCubit extends CollabPagedCubit<CollabReview> {
  CollabActorReviewsCubit(this._repository, {super.pageSize});

  final CollabRepository _repository;
  String? _actorId;

  String? get actorId => _actorId;

  Future<void> loadForActor(String actorId) {
    final normalized = actorId.trim();
    if (_actorId == normalized && state.items.isNotEmpty) {
      return refresh();
    }
    _actorId = normalized;
    return reloadForChangedFilter();
  }

  @override
  Future<Result<CollabPage<CollabReview>>> fetchPage(int page, int size) {
    final id = _actorId;
    if (id == null || id.isEmpty) {
      return Future<Result<CollabPage<CollabReview>>>.value(
        const Result<CollabPage<CollabReview>>.failure(
          AppError(
            code: 'collab_actor_id_required',
            message: 'Collab profili bulunamadı.',
          ),
        ),
      );
    }
    return _repository.getActorReviews(id, page: page, size: size);
  }

  @override
  String itemId(CollabReview item) => item.id;
}
