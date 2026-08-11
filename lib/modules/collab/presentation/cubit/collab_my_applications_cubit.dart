import '../../../../core/error/result.dart';
import '../../domain/collab_page.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_application.dart';
import 'collab_paged_cubit.dart';

class CollabMyApplicationsCubit extends CollabPagedCubit<CollabApplication> {
  CollabMyApplicationsCubit(this._repository, {super.pageSize});

  final CollabRepository _repository;
  CollabApplicationStatus? _statusFilter;

  CollabApplicationStatus? get statusFilter => _statusFilter;

  Future<void> setStatusFilter(CollabApplicationStatus? status) {
    if (_statusFilter == status) return Future<void>.value();
    _statusFilter = status;
    return reloadForChangedFilter();
  }

  @override
  Future<Result<CollabPage<CollabApplication>>> fetchPage(int page, int size) =>
      _repository.getMyApplications(
        status: _statusFilter,
        page: page,
        size: size,
      );

  @override
  String itemId(CollabApplication item) => item.id;

  Future<void> withdraw(CollabApplication application) async {
    if (!application.isPending || !beginItemAction(application.id)) return;
    final result = await _repository.withdrawApplication(
      application.id,
      expectedVersion: application.version,
    );
    if (isClosed) return;
    if (result.isSuccess) {
      final updated = result.data!;
      if (_statusFilter == null || _statusFilter == updated.status) {
        replaceItem(updated);
      } else {
        removeItem(updated.id);
      }
    }
    endItemAction(application.id, error: result.error);
  }

  Future<void> toggleSaved(CollabApplication application) async {
    if (!beginItemAction(application.id)) return;
    final listing = application.listing;
    final result = listing.savedByMe
        ? await _repository.unsaveListing(listing.id)
        : await _repository.saveListing(listing.id);
    if (isClosed) return;
    if (result.isSuccess) {
      replaceItem(
        application.copyWith(
          listing: listing.copyWith(savedByMe: !listing.savedByMe),
        ),
      );
    }
    endItemAction(application.id, error: result.error);
  }
}
