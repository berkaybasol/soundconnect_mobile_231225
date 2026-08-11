import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/collab_commands.dart';
import '../../domain/entities/collab_actor.dart';
import '../../domain/entities/collab_listing.dart';
import 'collab_async_state.dart';

enum CollabEditorOperation { idle, savingDraft, publishing, updating, deleting }

class CollabListingEditorState {
  const CollabListingEditorState({
    this.actorStatus = CollabLoadStatus.initial,
    this.actors = const <CollabActor>[],
    this.operation = CollabEditorOperation.idle,
    this.validationErrors = const <String>[],
    this.isDirty = false,
    this.input,
    this.listing,
    this.error,
  });

  final CollabLoadStatus actorStatus;
  final List<CollabActor> actors;
  final CollabEditorOperation operation;
  final CollabListingInput? input;
  final CollabListing? listing;
  final List<String> validationErrors;
  final bool isDirty;
  final AppError? error;

  bool get isSubmitting => operation != CollabEditorOperation.idle;
  CollabActor? get selectedActor {
    final actorId = input?.publisherActorId;
    for (final actor in actors) {
      if (actor.actorId == actorId) return actor;
    }
    return null;
  }

  CollabListingEditorState copyWith({
    CollabLoadStatus? actorStatus,
    List<CollabActor>? actors,
    CollabEditorOperation? operation,
    Object? input = copyWithUnset,
    Object? listing = copyWithUnset,
    List<String>? validationErrors,
    bool? isDirty,
    Object? error = copyWithUnset,
  }) => CollabListingEditorState(
    actorStatus: actorStatus ?? this.actorStatus,
    actors: actors ?? this.actors,
    operation: operation ?? this.operation,
    input: identical(input, copyWithUnset)
        ? this.input
        : input as CollabListingInput?,
    listing: identical(listing, copyWithUnset)
        ? this.listing
        : listing as CollabListing?,
    validationErrors: validationErrors ?? this.validationErrors,
    isDirty: isDirty ?? this.isDirty,
    error: identical(error, copyWithUnset) ? this.error : error as AppError?,
  );
}
