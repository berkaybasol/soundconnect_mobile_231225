import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../data/collab_idempotency_store.dart';
import '../../data/collab_request_canonicalizer.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_listing.dart';
import 'collab_async_state.dart';
import 'collab_conflict_support.dart';
import 'collab_listing_editor_state.dart';

class CollabListingEditorCubit extends Cubit<CollabListingEditorState> {
  CollabListingEditorCubit(
    this._repository, {
    String Function()? requestIdFactory,
    CollabIdempotencyStore? idempotencyStore,
  }) : _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       _idempotencyStore = idempotencyStore ?? MemoryCollabIdempotencyStore(),
       super(const CollabListingEditorState());

  final CollabRepository _repository;
  final String Function() _requestIdFactory;
  final CollabIdempotencyStore _idempotencyStore;
  int _generation = 0;

  Future<void> initialize({CollabListing? listing}) async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        actorStatus: CollabLoadStatus.loading,
        listing: listing,
        conflictListing: null,
        input: listing == null ? null : _inputFromListing(listing),
        isDirty: false,
        hasUnresolvedConflict: false,
        operation: CollabEditorOperation.idle,
        validationErrors: const <String>[],
        error: null,
      ),
    );
    final result = await _repository.getMyActors();
    if (isClosed || generation != _generation) return;
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          actorStatus: CollabLoadStatus.failure,
          error: result.error,
        ),
      );
      return;
    }
    final actors = result.data!;
    final currentInput = state.input;
    emit(
      state.copyWith(
        actorStatus: CollabLoadStatus.success,
        actors: actors,
        input: currentInput ?? _emptyInput(actors.firstOrNull?.actorId ?? ''),
        error: null,
      ),
    );
  }

  void updateInput(CollabListingInput input) {
    if (state.isSubmitting) return;
    final listing = state.listing;
    if (listing?.isOpen == true && listing!.applicationCount > 0) return;
    var normalized = input;
    if (normalized.wantedType != CollabProfileKind.musician) {
      normalized = normalized.copyWith(
        clearInstrumentId: true,
        clearBranch: true,
        clearCustomSpecialty: true,
      );
    }
    if (normalized.cadence == CollabCadence.regular) {
      normalized = normalized.copyWith(clearScheduledAt: true);
      final actor = state.actors
          .where((item) => item.actorId == normalized.publisherActorId)
          .firstOrNull;
      if (actor?.profileType != CollabProfileKind.venue) {
        normalized = normalized.copyWith(
          clearFeeAmount: true,
          clearCurrency: true,
        );
      }
    }
    emit(
      state.copyWith(
        input: normalized,
        isDirty: true,
        validationErrors: const <String>[],
        error: null,
      ),
    );
  }

  Future<void> saveDraft() async {
    final input = state.input;
    if (input == null || state.isSubmitting || state.hasUnresolvedConflict) {
      return;
    }
    final generation = _generation;
    final actor = state.selectedActor;
    if (actor == null) return;
    final errors = input.validate(
      publisherType: actor.profileType,
      latestScheduledAt: _latestScheduledAt,
    );
    if (errors.isNotEmpty) {
      emit(state.copyWith(validationErrors: errors, error: null));
      return;
    }
    emit(
      state.copyWith(
        operation: CollabEditorOperation.savingDraft,
        validationErrors: const <String>[],
        error: null,
      ),
    );
    final result = await _persistDraft(input);
    if (!_isCurrent(generation)) return;
    if (isCollabStaleUpdate(result.error)) {
      await _recoverFromStaleUpdate(
        listingId: state.listing!.id,
        conflict: result.error!,
        generation: generation,
      );
      return;
    }
    emit(
      state.copyWith(
        operation: CollabEditorOperation.idle,
        listing: result.data ?? state.listing,
        isDirty: !result.isSuccess,
        hasUnresolvedConflict: false,
        conflictListing: null,
        error: result.error,
      ),
    );
  }

  Future<void> publish() async {
    final input = state.input;
    final actor = state.selectedActor;
    if (input == null ||
        actor == null ||
        state.isSubmitting ||
        state.hasUnresolvedConflict) {
      return;
    }
    final generation = _generation;
    final errors = input.validate(
      publisherType: actor.profileType,
      latestScheduledAt: _latestScheduledAt,
    );
    if (errors.isNotEmpty) {
      emit(state.copyWith(validationErrors: errors, error: null));
      return;
    }
    emit(
      state.copyWith(
        operation: CollabEditorOperation.publishing,
        validationErrors: const <String>[],
        error: null,
      ),
    );
    var draft = state.listing;
    if (draft == null || state.isDirty) {
      final saveResult = await _persistDraft(input);
      if (!_isCurrent(generation)) return;
      if (!saveResult.isSuccess) {
        if (isCollabStaleUpdate(saveResult.error)) {
          await _recoverFromStaleUpdate(
            listingId: state.listing!.id,
            conflict: saveResult.error!,
            generation: generation,
          );
          return;
        }
        emit(
          state.copyWith(
            operation: CollabEditorOperation.idle,
            listing: saveResult.data ?? draft,
            error: saveResult.error,
          ),
        );
        return;
      }
      draft = saveResult.data;
      emit(state.copyWith(listing: draft, isDirty: false));
    }
    if (draft == null || !draft.isDraft) {
      emit(
        state.copyWith(
          operation: CollabEditorOperation.idle,
          error: const AppError(
            code: 'collab_draft_required',
            message: 'Yayınlanabilir bir taslak bulunamadı.',
          ),
        ),
      );
      return;
    }
    final result = await _repository.publishDraft(
      draft.id,
      expectedVersion: draft.version,
    );
    if (!_isCurrent(generation)) return;
    if (isCollabStaleUpdate(result.error)) {
      await _recoverFromStaleUpdate(
        listingId: draft.id,
        conflict: result.error!,
        generation: generation,
      );
      return;
    }
    emit(
      state.copyWith(
        operation: CollabEditorOperation.idle,
        listing: result.data ?? draft,
        isDirty: false,
        hasUnresolvedConflict: false,
        conflictListing: null,
        error: result.error,
      ),
    );
  }

  Future<void> updateOpenListing() async {
    final input = state.input;
    final listing = state.listing;
    final actor = state.selectedActor;
    if (input == null ||
        listing == null ||
        actor == null ||
        listing.isDraft ||
        state.isSubmitting ||
        state.hasUnresolvedConflict) {
      return;
    }
    final generation = _generation;
    if (listing.applicationCount > 0) {
      emit(
        state.copyWith(
          error: const AppError(
            code: 'collab_published_edit_restricted',
            message: 'Başvuru alan açık ilanın iş şartları değiştirilemez.',
          ),
        ),
      );
      return;
    }
    final errors = input.validate(
      publisherType: actor.profileType,
      latestScheduledAt: _latestScheduledAt,
    );
    if (errors.isNotEmpty) {
      emit(state.copyWith(validationErrors: errors));
      return;
    }
    emit(
      state.copyWith(
        operation: CollabEditorOperation.updating,
        validationErrors: const <String>[],
        error: null,
      ),
    );
    final result = await _repository.updateListing(
      listing.id,
      input,
      expectedVersion: listing.version,
    );
    if (!_isCurrent(generation)) return;
    if (isCollabStaleUpdate(result.error)) {
      await _recoverFromStaleUpdate(
        listingId: listing.id,
        conflict: result.error!,
        generation: generation,
      );
      return;
    }
    emit(
      state.copyWith(
        operation: CollabEditorOperation.idle,
        listing: result.data ?? listing,
        isDirty: !result.isSuccess,
        hasUnresolvedConflict: false,
        conflictListing: null,
        error: result.error,
      ),
    );
  }

  Future<void> deleteDraft() async {
    final listing = state.listing;
    if (listing == null ||
        !listing.isDraft ||
        state.isSubmitting ||
        state.hasUnresolvedConflict) {
      return;
    }
    final generation = _generation;
    emit(
      state.copyWith(operation: CollabEditorOperation.deleting, error: null),
    );
    final result = await _repository.deleteDraft(
      listing.id,
      expectedVersion: listing.version,
    );
    if (!_isCurrent(generation)) return;
    if (isCollabStaleUpdate(result.error)) {
      await _recoverFromStaleUpdate(
        listingId: listing.id,
        conflict: result.error!,
        generation: generation,
      );
      return;
    }
    emit(
      state.copyWith(
        operation: CollabEditorOperation.idle,
        listing: result.isSuccess ? null : listing,
        isDirty: result.isSuccess ? false : state.isDirty,
        hasUnresolvedConflict: false,
        conflictListing: null,
        error: result.error,
      ),
    );
  }

  Future<Result<CollabListing>> _persistDraft(CollabListingInput input) async {
    final existing = state.listing;
    if (existing == null) {
      final canonicalInput = canonicalCollabListingInput(input);
      try {
        final lease = await _idempotencyStore.acquire(
          operation: 'create_listing',
          targetId: 'new',
          payloadFingerprint: _listingPayloadFingerprint(canonicalInput),
          createRequestId: _requestIdFactory,
        );
        final result = await _repository.createDraft(
          canonicalInput,
          clientRequestId: lease.requestId,
        );
        if (result.isSuccess) {
          try {
            await _idempotencyStore.complete(lease);
          } catch (_) {
            // The authoritative create response must not be converted to a
            // failure by best-effort local cleanup. TTL/reset semantics keep a
            // stale lease from replaying forever.
          }
        }
        return result;
      } catch (_) {
        return const Result<CollabListing>.failure(
          AppError(
            code: 'collab_idempotency_storage',
            message:
                'Güvenli istek anahtarı hazırlanamadı. Lütfen tekrar dene.',
          ),
        );
      }
    }
    if (!existing.isDraft) {
      return Future<Result<CollabListing>>.value(
        const Result<CollabListing>.failure(
          AppError(
            code: 'collab_listing_not_draft',
            message: 'Yalnız taslak ilan bu işlemle kaydedilebilir.',
          ),
        ),
      );
    }
    return _repository.updateDraft(
      existing.id,
      input,
      expectedVersion: existing.version,
    );
  }

  Future<void> _recoverFromStaleUpdate({
    required String listingId,
    required AppError conflict,
    required int generation,
  }) async {
    final latestResult = await _repository.getListing(listingId);
    if (!_isCurrent(generation)) return;

    final latest = latestResult.data;
    if (latestResult.isSuccess && latest != null) {
      emit(
        state.copyWith(
          operation: CollabEditorOperation.idle,
          conflictListing: latest,
          isDirty: true,
          hasUnresolvedConflict: true,
          validationErrors: const <String>[],
          error: collabPreservedConflictError(conflict),
        ),
      );
      return;
    }

    if (isCollabListingNotFound(latestResult.error)) {
      emit(
        state.copyWith(
          operation: CollabEditorOperation.idle,
          conflictListing: null,
          isDirty: true,
          hasUnresolvedConflict: true,
          validationErrors: const <String>[],
          error: collabDeletedConflictError(conflict),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        operation: CollabEditorOperation.idle,
        conflictListing: null,
        isDirty: true,
        hasUnresolvedConflict: true,
        error: collabUnresolvedConflictError(conflict),
      ),
    );
  }

  void keepLocalConflictForm() {
    if (!state.hasUnresolvedConflict || isClosed) return;
    emit(state.copyWith(error: null));
  }

  void loadLatestConflictVersion() {
    final latest = state.conflictListing;
    if (!state.hasUnresolvedConflict || latest == null || isClosed) return;
    emit(
      state.copyWith(
        listing: latest,
        conflictListing: null,
        input: _inputFromListing(latest),
        isDirty: false,
        hasUnresolvedConflict: false,
        validationErrors: const <String>[],
        error: null,
      ),
    );
  }

  bool _isCurrent(int generation) {
    return !isClosed && generation == _generation;
  }

  Future<bool> abandonPendingCreate() async {
    if (state.listing != null) return true;
    try {
      await _idempotencyStore.resetOperation(
        operation: 'create_listing',
        targetId: 'new',
      );
      return true;
    } catch (_) {
      if (!isClosed) {
        emit(
          state.copyWith(
            error: const AppError(
              code: 'collab_idempotency_reset',
              message:
                  'Yeni ilan denemesi güvenle sıfırlanamadı. Lütfen tekrar dene.',
            ),
          ),
        );
      }
      return false;
    }
  }

  CollabListingInput _emptyInput(String actorId) => CollabListingInput(
    publisherActorId: actorId,
    cadence: CollabCadence.regular,
    wantedType: CollabProfileKind.musician,
    title: '',
    description: '',
    cityId: '',
  );

  CollabListingInput _inputFromListing(CollabListing listing) =>
      CollabListingInput(
        publisherActorId: listing.publisher.actorId,
        cadence: listing.cadence,
        wantedType: listing.wantedType,
        instrumentId: listing.instrument?.id,
        branch: listing.branch,
        customSpecialty: listing.customSpecialty,
        title: listing.title,
        description: listing.description,
        cityId: listing.city.id,
        genres: listing.genres,
        scheduledAt: listing.scheduledAt,
        feeAmountMinor: listing.feeAmountMinor,
        currency: listing.currency,
      );

  String _listingPayloadFingerprint(CollabListingInput input) =>
      jsonEncode(<String, Object?>{
        'publisherActorId': input.publisherActorId,
        'cadence': input.cadence.apiValue,
        'wantedType': input.wantedType.apiValue,
        'instrumentId': input.instrumentId,
        'branch': input.branch?.apiValue,
        'customSpecialty': input.customSpecialty,
        'title': input.title,
        'description': input.description,
        'cityId': input.cityId,
        'genres': input.genres,
        'scheduledAt': input.scheduledAt?.toIso8601String(),
        'feeAmountMinor': input.feeAmountMinor,
        'currency': input.currency,
      });

  DateTime? get _latestScheduledAt {
    final listing = state.listing;
    final publishedAt = listing?.publishedAt;
    if (listing?.isOpen != true || publishedAt == null) return null;
    return publishedAt.add(const Duration(days: 7));
  }
}
