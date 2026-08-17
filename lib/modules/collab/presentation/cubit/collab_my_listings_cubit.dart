import '../../../../core/error/result.dart';
import '../../domain/collab_page.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_listing.dart';
import 'collab_conflict_support.dart';
import 'collab_paged_cubit.dart';

class CollabMyListingsCubit extends CollabPagedCubit<CollabListing> {
  CollabMyListingsCubit(this._repository, {super.pageSize});

  final CollabRepository _repository;
  CollabListingStatus? _statusFilter;

  CollabListingStatus? get statusFilter => _statusFilter;

  Future<void> setStatusFilter(CollabListingStatus? status) {
    if (_statusFilter == status) return Future<void>.value();
    _statusFilter = status;
    return reloadForChangedFilter();
  }

  @override
  Future<Result<CollabPage<CollabListing>>> fetchPage(int page, int size) =>
      _repository.getMyListings(status: _statusFilter, page: page, size: size);

  @override
  String itemId(CollabListing item) => item.id;

  Future<void> closeListing(CollabListing listing) async {
    if (!listing.isOpen || !beginItemAction(listing.id)) return;
    final generation = operationGeneration;
    final result = await _repository.closeListing(
      listing.id,
      expectedVersion: listing.version,
    );
    if (!isCurrentOperation(generation)) {
      if (!isClosed) endItemAction(listing.id);
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
    endItemAction(listing.id, error: result.error);
  }

  Future<void> deleteDraft(CollabListing listing) async {
    if (!listing.isDraft || !beginItemAction(listing.id)) return;
    final generation = operationGeneration;
    final result = await _repository.deleteDraft(
      listing.id,
      expectedVersion: listing.version,
    );
    if (!isCurrentOperation(generation)) {
      if (!isClosed) endItemAction(listing.id);
      return;
    }
    if (result.isSuccess) {
      await removeItemAndRefresh(listing.id);
      if (isClosed) return;
    } else if (isCollabStaleUpdate(result.error)) {
      await refresh();
      if (isClosed) return;
    }
    endItemAction(listing.id, error: result.error);
  }
}
