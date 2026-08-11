import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/collab_application.dart';
import '../../domain/entities/collab_actor.dart';
import '../../domain/entities/collab_listing.dart';
import 'collab_async_state.dart';

class CollabListingDetailState {
  const CollabListingDetailState({
    this.status = CollabLoadStatus.initial,
    this.actorStatus = CollabLoadStatus.initial,
    this.actors = const <CollabActor>[],
    this.isSaving = false,
    this.isApplying = false,
    this.isClosing = false,
    this.isReporting = false,
    this.error,
    this.actionError,
    this.actorError,
    this.listing,
    this.application,
    this.reportSubmitted = false,
  });

  final CollabLoadStatus status;
  final CollabLoadStatus actorStatus;
  final List<CollabActor> actors;
  final CollabListing? listing;
  final CollabApplication? application;
  final bool isSaving;
  final bool isApplying;
  final bool isClosing;
  final bool isReporting;
  final bool reportSubmitted;
  final AppError? error;
  final AppError? actionError;
  final AppError? actorError;

  List<CollabActor> get eligibleActors {
    final wantedType = listing?.wantedType;
    if (wantedType == null) return const <CollabActor>[];
    return List<CollabActor>.unmodifiable(
      actors.where((actor) => actor.profileType == wantedType),
    );
  }

  CollabListingDetailState copyWith({
    CollabLoadStatus? status,
    CollabLoadStatus? actorStatus,
    List<CollabActor>? actors,
    Object? listing = copyWithUnset,
    Object? application = copyWithUnset,
    bool? isSaving,
    bool? isApplying,
    bool? isClosing,
    bool? isReporting,
    bool? reportSubmitted,
    Object? error = copyWithUnset,
    Object? actionError = copyWithUnset,
    Object? actorError = copyWithUnset,
  }) => CollabListingDetailState(
    status: status ?? this.status,
    actorStatus: actorStatus ?? this.actorStatus,
    actors: actors ?? this.actors,
    listing: identical(listing, copyWithUnset)
        ? this.listing
        : listing as CollabListing?,
    application: identical(application, copyWithUnset)
        ? this.application
        : application as CollabApplication?,
    isSaving: isSaving ?? this.isSaving,
    isApplying: isApplying ?? this.isApplying,
    isClosing: isClosing ?? this.isClosing,
    isReporting: isReporting ?? this.isReporting,
    reportSubmitted: reportSubmitted ?? this.reportSubmitted,
    error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    actionError: identical(actionError, copyWithUnset)
        ? this.actionError
        : actionError as AppError?,
    actorError: identical(actorError, copyWithUnset)
        ? this.actorError
        : actorError as AppError?,
  );
}
