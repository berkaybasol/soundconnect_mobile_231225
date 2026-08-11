import '../../../../core/error/result.dart';
import '../../domain/collab_page.dart';
import '../../domain/collab_repository.dart';
import '../../domain/entities/collab_listing.dart';
import 'collab_paged_cubit.dart';

class CollabSavedListingsCubit extends CollabPagedCubit<CollabListing> {
  CollabSavedListingsCubit(this._repository, {super.pageSize});

  final CollabRepository _repository;

  @override
  Future<Result<CollabPage<CollabListing>>> fetchPage(int page, int size) =>
      _repository.getSavedListings(page: page, size: size);

  @override
  String itemId(CollabListing item) => item.id;

  Future<void> unsave(CollabListing listing) async {
    if (!beginItemAction(listing.id)) return;
    final result = await _repository.unsaveListing(listing.id);
    if (isClosed) return;
    if (result.isSuccess) removeItem(listing.id);
    endItemAction(listing.id, error: result.error);
  }
}
