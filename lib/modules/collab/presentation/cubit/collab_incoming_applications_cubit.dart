import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../domain/collab_page.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_application.dart';
import 'collab_conflict_support.dart';
import 'collab_paged_cubit.dart';

class CollabIncomingApplicationsCubit
    extends CollabPagedCubit<CollabApplication> {
  CollabIncomingApplicationsCubit(this._repository, {super.pageSize});

  final CollabRepository _repository;
  String? _listingId;
  CollabApplicationStatus? _statusFilter;

  String? get listingId => _listingId;
  CollabApplicationStatus? get statusFilter => _statusFilter;

  Future<void> loadForListing(String listingId) {
    _listingId = listingId;
    return reloadForChangedFilter();
  }

  Future<void> setStatusFilter(CollabApplicationStatus? status) {
    if (_statusFilter == status) return Future<void>.value();
    _statusFilter = status;
    return reloadForChangedFilter();
  }

  @override
  Future<Result<CollabPage<CollabApplication>>> fetchPage(int page, int size) {
    final id = _listingId;
    if (id == null || id.trim().isEmpty) {
      return Future<Result<CollabPage<CollabApplication>>>.value(
        const Result<CollabPage<CollabApplication>>.failure(
          AppError(
            code: 'collab_listing_id_required',
            message: 'İlan kimliği eksik.',
          ),
        ),
      );
    }
    return _repository.getIncomingApplications(
      id,
      status: _statusFilter,
      page: page,
      size: size,
    );
  }

  @override
  String itemId(CollabApplication item) => item.id;

  Future<void> accept(CollabApplication application) async {
    if (!application.isPending || !beginItemAction(application.id)) return;
    final generation = operationGeneration;
    final result = await _repository.acceptApplication(
      application.id,
      expectedVersion: application.version,
    );
    if (!isCurrentOperation(generation)) {
      if (!isClosed) endItemAction(application.id);
      return;
    }
    if (result.isSuccess || isCollabStaleUpdate(result.error)) {
      // Accept closes the listing and invalidates every other pending
      // application atomically. A version conflict also means another device
      // changed the authoritative state, so refresh without retrying.
      await refresh();
    }
    if (!isClosed) endItemAction(application.id, error: result.error);
  }

  Future<void> reject(CollabApplication application) async {
    if (!application.isPending || !beginItemAction(application.id)) return;
    final generation = operationGeneration;
    final result = await _repository.rejectApplication(
      application.id,
      expectedVersion: application.version,
    );
    if (!isCurrentOperation(generation)) {
      if (!isClosed) endItemAction(application.id);
      return;
    }
    if (result.isSuccess) {
      final updated = result.data!;
      if (_statusFilter == null || _statusFilter == updated.status) {
        replaceItem(updated);
      } else {
        await removeItemAndRefresh(updated.id);
        if (isClosed) return;
      }
    } else if (isCollabStaleUpdate(result.error)) {
      await refresh();
      if (isClosed) return;
    }
    if (isClosed) return;
    endItemAction(application.id, error: result.error);
  }
}
