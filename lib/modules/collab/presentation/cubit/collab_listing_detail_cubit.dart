import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/collab_commands.dart';
import '../../domain/collab_repository.dart';
import '../../domain/collab_types.dart';
import 'collab_async_state.dart';
import 'collab_listing_detail_state.dart';

class CollabListingDetailCubit extends Cubit<CollabListingDetailState> {
  CollabListingDetailCubit(
    this._repository, {
    String Function()? requestIdFactory,
  }) : _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       super(const CollabListingDetailState());

  final CollabRepository _repository;
  final String Function() _requestIdFactory;
  String? _applicationRequestId;
  String? _applicationPayloadFingerprint;
  String? _reportRequestId;
  String? _reportPayloadFingerprint;
  int _generation = 0;

  Future<void> load(String listingId) async {
    final generation = ++_generation;
    _applicationRequestId = null;
    _applicationPayloadFingerprint = null;
    _reportRequestId = null;
    _reportPayloadFingerprint = null;
    emit(
      state.copyWith(
        status: CollabLoadStatus.loading,
        listing: null,
        application: null,
        error: null,
        actionError: null,
        reportSubmitted: false,
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
    emit(
      state.copyWith(actorStatus: CollabLoadStatus.loading, actorError: null),
    );
    final result = await _repository.getMyActors();
    if (isClosed) return;
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
    if (listing == null || state.isSaving) return;
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
    if (isClosed) return;
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
    final fingerprint = _applicationFingerprint(input);
    if (_applicationRequestId == null ||
        _applicationPayloadFingerprint != fingerprint) {
      _applicationRequestId = _requestIdFactory();
      _applicationPayloadFingerprint = fingerprint;
    }
    final requestId = _applicationRequestId!;
    emit(state.copyWith(isApplying: true, actionError: null));
    final result = await _repository.apply(
      listing.id,
      input,
      clientRequestId: requestId,
    );
    if (isClosed) return;
    if (result.isSuccess) {
      _applicationRequestId = null;
      _applicationPayloadFingerprint = null;
      emit(
        state.copyWith(
          listing: listing.copyWith(appliedByMe: true),
          application: result.data,
          isApplying: false,
          actionError: null,
        ),
      );
    } else {
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
    emit(state.copyWith(isClosing: true, actionError: null));
    final result = await _repository.closeListing(
      listing.id,
      expectedVersion: listing.version,
    );
    if (isClosed) return;
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
    final fingerprint = _reportFingerprint(input);
    if (_reportRequestId == null || _reportPayloadFingerprint != fingerprint) {
      _reportRequestId = _requestIdFactory();
      _reportPayloadFingerprint = fingerprint;
    }
    final requestId = _reportRequestId!;
    emit(state.copyWith(isReporting: true, actionError: null));
    final result = await _repository.reportListing(
      listing.id,
      input,
      clientRequestId: requestId,
    );
    if (isClosed) return;
    if (result.isSuccess) {
      _reportRequestId = null;
      _reportPayloadFingerprint = null;
    }
    emit(
      state.copyWith(
        isReporting: false,
        reportSubmitted: result.isSuccess,
        actionError: result.error,
      ),
    );
  }

  String _applicationFingerprint(CollabApplicationInput input) =>
      jsonEncode(<String, Object?>{
        'applicantActorId': input.applicantActorId.trim(),
        'phone': input.phone.trim(),
        'message': input.message.trim(),
      });

  String _reportFingerprint(CollabReportInput input) =>
      jsonEncode(<String, Object?>{
        'reason': input.reason.apiValue,
        'details': input.details?.trim(),
      });
}
