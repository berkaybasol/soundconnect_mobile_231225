import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/app_error.dart';
import '../../data/collab_idempotency_store.dart';
import '../../data/collab_request_canonicalizer.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import 'collab_async_state.dart';
import 'collab_conflict_support.dart';
import 'collab_listing_detail_state.dart';

class CollabListingDetailCubit extends Cubit<CollabListingDetailState> {
  CollabListingDetailCubit(
    this._repository, {
    String Function()? requestIdFactory,
    CollabIdempotencyStore? idempotencyStore,
  }) : _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       _idempotencyStore = idempotencyStore ?? MemoryCollabIdempotencyStore(),
       super(const CollabListingDetailState());

  final CollabRepository _repository;
  final String Function() _requestIdFactory;
  final CollabIdempotencyStore _idempotencyStore;
  int _generation = 0;
  int _actorGeneration = 0;

  Future<void> load(String listingId) async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: CollabLoadStatus.loading,
        listing: null,
        application: null,
        error: null,
        actionError: null,
        reportSubmitted: false,
        isSaving: false,
        isApplying: false,
        isClosing: false,
        isReporting: false,
      ),
    );
    final result = await _repository.getListing(listingId);
    if (isClosed || generation != _generation) return;
    if (result.isSuccess) {
      emit(
        state.copyWith(
          status: CollabLoadStatus.success,
          listing: result.data,
          error: null,
        ),
      );
    } else {
      emit(
        state.copyWith(status: CollabLoadStatus.failure, error: result.error),
      );
    }
  }

  Future<void> refresh() async {
    final listingId = state.listing?.id;
    if (listingId != null) await load(listingId);
  }

  Future<void> loadMyActors({bool force = false}) async {
    if (!force &&
        (state.actorStatus == CollabLoadStatus.loading ||
            state.actorStatus == CollabLoadStatus.success)) {
      return;
    }
    final generation = ++_actorGeneration;
    emit(
      state.copyWith(actorStatus: CollabLoadStatus.loading, actorError: null),
    );
    final result = await _repository.getMyActors();
    if (isClosed || generation != _actorGeneration) return;
    emit(
      state.copyWith(
        actorStatus: result.isSuccess
            ? CollabLoadStatus.success
            : CollabLoadStatus.failure,
        actors: result.data ?? state.actors,
        actorError: result.error,
      ),
    );
  }

  Future<void> toggleSaved() async {
    final listing = state.listing;
    if (listing == null ||
        !listing.isOpen ||
        listing.ownedByMe ||
        state.isSaving) {
      return;
    }
    final generation = _generation;
    final nextSaved = !listing.savedByMe;
    emit(
      state.copyWith(
        listing: listing.copyWith(savedByMe: nextSaved),
        isSaving: true,
        actionError: null,
      ),
    );
    final result = nextSaved
        ? await _repository.saveListing(listing.id)
        : await _repository.unsaveListing(listing.id);
    if (!_isCurrent(generation)) return;
    emit(
      state.copyWith(
        listing: result.isSuccess ? state.listing : listing,
        isSaving: false,
        actionError: result.error,
      ),
    );
  }

  Future<void> apply(CollabApplicationInput input) async {
    final listing = state.listing;
    if (listing == null || state.isApplying || !listing.canApply) return;
    final generation = _generation;
    final canonicalInput = canonicalCollabApplicationInput(input);
    emit(state.copyWith(isApplying: true, actionError: null));
    late final CollabIdempotencyLease lease;
    try {
      lease = await _idempotencyStore.acquire(
        operation: 'apply',
        targetId: listing.id,
        payloadFingerprint: _applicationFingerprint(canonicalInput),
        createRequestId: _requestIdFactory,
      );
    } catch (_) {
      if (_isCurrent(generation)) {
        emit(state.copyWith(isApplying: false, actionError: _idempotencyError));
      }
      return;
    }
    if (!_isCurrent(generation)) return;
    final result = await _repository.apply(
      listing.id,
      canonicalInput,
      clientRequestId: lease.requestId,
    );
    if (result.isSuccess) {
      AppError? cleanupError;
      try {
        await _idempotencyStore.complete(lease);
      } catch (_) {
        cleanupError = _idempotencyCleanupError;
      }
      if (!_isCurrent(generation)) return;
      emit(
        state.copyWith(
          listing: listing.copyWith(appliedByMe: true),
          application: result.data,
          isApplying: false,
          actionError: cleanupError,
        ),
      );
    } else {
      if (!_isCurrent(generation)) return;
      emit(state.copyWith(isApplying: false, actionError: result.error));
    }
  }

  Future<void> closeListing() async {
    final listing = state.listing;
    if (listing == null ||
        !listing.ownedByMe ||
        !listing.isOpen ||
        state.isClosing) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(isClosing: true, actionError: null));
    final result = await _repository.closeListing(
      listing.id,
      expectedVersion: listing.version,
    );
    if (!_isCurrent(generation)) return;
    if (isCollabStaleUpdate(result.error)) {
      final conflict = result.error;
      await load(listing.id);
      if (!isClosed && conflict != null) {
        emit(state.copyWith(isClosing: false, actionError: conflict));
      }
      return;
    }
    emit(
      state.copyWith(
        listing: result.data ?? listing,
        isClosing: false,
        actionError: result.error,
      ),
    );
  }

  Future<void> report(CollabReportInput input) async {
    final listing = state.listing;
    if (listing == null || state.isReporting || state.reportSubmitted) return;
    final generation = _generation;
    final canonicalInput = canonicalCollabReportInput(input);
    emit(state.copyWith(isReporting: true, actionError: null));
    late final CollabIdempotencyLease lease;
    try {
      lease = await _idempotencyStore.acquire(
        operation: 'report',
        targetId: listing.id,
        payloadFingerprint: _reportFingerprint(canonicalInput),
        createRequestId: _requestIdFactory,
      );
    } catch (_) {
      if (_isCurrent(generation)) {
        emit(
          state.copyWith(isReporting: false, actionError: _idempotencyError),
        );
      }
      return;
    }
    if (!_isCurrent(generation)) return;
    final result = await _repository.reportListing(
      listing.id,
      canonicalInput,
      clientRequestId: lease.requestId,
    );
    AppError? cleanupError;
    if (result.isSuccess) {
      try {
        await _idempotencyStore.complete(lease);
      } catch (_) {
        cleanupError = _idempotencyCleanupError;
      }
    }
    if (!_isCurrent(generation)) return;
    emit(
      state.copyWith(
        isReporting: false,
        reportSubmitted: result.isSuccess,
        actionError: result.error ?? cleanupError,
      ),
    );
  }

  bool _isCurrent(int generation) {
    return !isClosed && generation == _generation;
  }

  String _applicationFingerprint(CollabApplicationInput input) =>
      jsonEncode(<String, Object?>{
        'applicantActorId': input.applicantActorId,
        'phone': input.phone,
        'message': canonicalCollabOptionalText(input.message),
      });

  String _reportFingerprint(CollabReportInput input) =>
      jsonEncode(<String, Object?>{
        'reason': input.reason.apiValue,
        'details': input.details,
      });

  static const AppError _idempotencyError = AppError(
    code: 'collab_idempotency_storage',
    message: 'Güvenli istek anahtarı hazırlanamadı. Lütfen tekrar dene.',
  );

  static const AppError _idempotencyCleanupError = AppError(
    code: 'collab_idempotency_cleanup',
    message: 'İşlem tamamlandı ancak yerel istek anahtarı temizlenemedi.',
  );
}
