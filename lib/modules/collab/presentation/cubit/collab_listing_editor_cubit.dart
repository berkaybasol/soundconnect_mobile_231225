import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../domain/collab_commands.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_listing.dart';
import 'collab_async_state.dart';
import 'collab_listing_editor_state.dart';

class CollabListingEditorCubit extends Cubit<CollabListingEditorState> {
  CollabListingEditorCubit(
    this._repository, {
    String Function()? requestIdFactory,
  }) : _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       super(const CollabListingEditorState());

  final CollabRepository _repository;
  final String Function() _requestIdFactory;
  String? _createRequestId;
  String? _createPayloadFingerprint;
  int _generation = 0;

  Future<void> initialize({CollabListing? listing}) async {
    final generation = ++_generation;
    _createRequestId = null;
    _createPayloadFingerprint = null;
    emit(
      state.copyWith(
        actorStatus: CollabLoadStatus.loading,
        listing: listing,
        input: listing == null ? null : _inputFromListing(listing),
        isDirty: false,
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
    if (input == null || state.isSubmitting) return;
    final actor = state.selectedActor;
    if (actor == null) return;
    final errors = input.validate(publisherType: actor.profileType);
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
    if (isClosed) return;
    emit(
      state.copyWith(
        operation: CollabEditorOperation.idle,
        listing: result.data ?? state.listing,
        isDirty: !result.isSuccess,
        error: result.error,
      ),
    );
  }

  Future<void> publish() async {
    final input = state.input;
    final actor = state.selectedActor;
    if (input == null || actor == null || state.isSubmitting) return;
    final errors = input.validate(publisherType: actor.profileType);
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
      if (isClosed) return;
      if (!saveResult.isSuccess) {
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
    if (isClosed) return;
    if (result.isSuccess) {
      _createRequestId = null;
      _createPayloadFingerprint = null;
    }
    emit(
      state.copyWith(
        operation: CollabEditorOperation.idle,
        listing: result.data ?? draft,
        isDirty: false,
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
        state.isSubmitting) {
      return;
    }
    final errors = input.validate(publisherType: actor.profileType);
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
    if (isClosed) return;
    emit(
      state.copyWith(
        operation: CollabEditorOperation.idle,
        listing: result.data ?? listing,
        isDirty: !result.isSuccess,
        error: result.error,
      ),
    );
  }

  Future<void> deleteDraft() async {
    final listing = state.listing;
    if (listing == null || !listing.isDraft || state.isSubmitting) return;
    emit(
      state.copyWith(operation: CollabEditorOperation.deleting, error: null),
    );
    final result = await _repository.deleteDraft(
      listing.id,
      expectedVersion: listing.version,
    );
    if (isClosed) return;
    if (result.isSuccess) {
      _createRequestId = null;
      _createPayloadFingerprint = null;
    }
    emit(
      state.copyWith(
        operation: CollabEditorOperation.idle,
        listing: result.isSuccess ? null : listing,
        isDirty: result.isSuccess ? true : state.isDirty,
        error: result.error,
      ),
    );
  }

  Future<Result<CollabListing>> _persistDraft(CollabListingInput input) {
    final existing = state.listing;
    if (existing == null) {
      final fingerprint = _listingPayloadFingerprint(input);
      if (_createRequestId == null ||
          _createPayloadFingerprint != fingerprint) {
        _createRequestId = _requestIdFactory();
        _createPayloadFingerprint = fingerprint;
      }
      final requestId = _createRequestId!;
      return _repository.createDraft(input, clientRequestId: requestId);
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
        'publisherActorId': input.publisherActorId.trim(),
        'cadence': input.cadence.apiValue,
        'wantedType': input.wantedType.apiValue,
        'instrumentId': input.instrumentId?.trim(),
        'branch': input.branch?.apiValue,
        'customSpecialty': input.customSpecialty?.trim(),
        'title': input.title.trim(),
        'description': input.description.trim(),
        'cityId': input.cityId.trim(),
        'genres': input.genres.map((item) => item.trim()).toList(),
        'scheduledAt': input.scheduledAt?.toUtc().toIso8601String(),
        'feeAmountMinor': input.feeAmountMinor,
        'currency': input.currency?.trim().toUpperCase(),
      });
}
