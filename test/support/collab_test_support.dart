import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_commands.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_actor.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_application.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_listing.dart';

const musicianActor = CollabActor(
  actorId: 'actor-musician',
  profileType: CollabProfileKind.musician,
  sourceProfileId: 'musician-profile-1',
  contactUserId: 'user-musician',
  displayName: 'Deniz Kaya',
  rating: 4.9,
  reviewCount: 18,
  completedJobCount: 32,
);

const bandActor = CollabActor(
  actorId: 'actor-band',
  profileType: CollabProfileKind.band,
  sourceProfileId: 'band-profile-1',
  contactUserId: 'user-band',
  displayName: 'Acoustic Route',
  rating: 4.7,
  reviewCount: 9,
  completedJobCount: 21,
);

const venueActor = CollabActor(
  actorId: 'actor-venue',
  profileType: CollabProfileKind.venue,
  sourceProfileId: 'venue-profile-1',
  contactUserId: 'user-venue',
  displayName: 'Kadıköy Sahne',
  rating: 4.8,
  reviewCount: 42,
  completedJobCount: 128,
);

CollabListing collabListingFixture({
  String id = 'listing-1',
  CollabCadence cadence = CollabCadence.extra,
  CollabProfileKind wantedType = CollabProfileKind.musician,
  CollabActor publisher = venueActor,
  CollabListingStatus status = CollabListingStatus.open,
  int? feeAmountMinor = 150075,
  bool ownedByMe = false,
  bool appliedByMe = false,
  bool savedByMe = false,
}) => CollabListing(
  id: id,
  version: 3,
  status: status,
  cadence: cadence,
  wantedType: wantedType,
  instrument: wantedType == CollabProfileKind.musician
      ? const CollabInstrumentSummary(id: 'instrument-bass', name: 'Bas Gitar')
      : null,
  title: 'Çarşamba gecesi bas gitarist arıyoruz',
  description: 'Sahnemiz için repertuvara hakim bir bas gitarist arıyoruz.',
  city: const CollabCitySummary(id: 'city-34', name: 'İstanbul'),
  genres: const <String>['Funk', 'Rock', 'Alternatif'],
  scheduledAt: cadence == CollabCadence.extra
      ? DateTime.utc(2026, 8, 12, 19, 30)
      : null,
  expiresAt: DateTime.utc(2026, 8, 12, 19, 30),
  feeAmountMinor: feeAmountMinor,
  currency: feeAmountMinor == null ? null : 'TRY',
  feeStatus: feeAmountMinor == null
      ? CollabFeeStatus.unspecified
      : CollabFeeStatus.specified,
  publishedAt: DateTime.utc(2026, 8, 11, 10),
  createdAt: DateTime.utc(2026, 8, 11, 9),
  publisher: publisher,
  ownedByMe: ownedByMe,
  appliedByMe: appliedByMe,
  savedByMe: savedByMe,
);

class FakeCollabDetailRepository implements CollabRepository {
  FakeCollabDetailRepository({
    required this.listing,
    this.actors = const <CollabActor>[musicianActor, bandActor],
  });

  CollabListing listing;
  List<CollabActor> actors;
  AppError? detailError;
  AppError? applyError;
  int detailCalls = 0;
  int applyCalls = 0;
  int saveCalls = 0;
  int unsaveCalls = 0;
  int closeCalls = 0;
  int reportCalls = 0;
  CollabApplicationInput? lastApplicationInput;

  @override
  Future<Result<CollabListing>> getListing(String listingId) async {
    detailCalls++;
    final error = detailError;
    if (error != null) return Result<CollabListing>.failure(error);
    return Result<CollabListing>.success(listing);
  }

  @override
  Future<Result<List<CollabActor>>> getMyActors() async =>
      Result<List<CollabActor>>.success(actors);

  @override
  Future<Result<void>> saveListing(String listingId) async {
    saveCalls++;
    listing = listing.copyWith(savedByMe: true);
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> unsaveListing(String listingId) async {
    unsaveCalls++;
    listing = listing.copyWith(savedByMe: false);
    return const Result<void>.success(null);
  }

  @override
  Future<Result<CollabApplication>> apply(
    String listingId,
    CollabApplicationInput input, {
    required String clientRequestId,
  }) async {
    applyCalls++;
    lastApplicationInput = input;
    final error = applyError;
    if (error != null) {
      applyError = null;
      return Result<CollabApplication>.failure(error);
    }
    listing = listing.copyWith(appliedByMe: true);
    final now = DateTime.utc(2026, 8, 11, 12);
    return Result<CollabApplication>.success(
      CollabApplication(
        id: 'application-1',
        version: 0,
        listing: listing,
        applicant: actors.firstWhere(
          (actor) => actor.actorId == input.applicantActorId,
        ),
        phone: input.phone,
        message: input.message,
        status: CollabApplicationStatus.pending,
        submittedAt: now,
        statusChangedAt: now,
      ),
    );
  }

  @override
  Future<Result<CollabListing>> closeListing(
    String listingId, {
    required int expectedVersion,
  }) async {
    closeCalls++;
    listing = listing.copyWith(status: CollabListingStatus.closed);
    return Result<CollabListing>.success(listing);
  }

  @override
  Future<Result<void>> reportListing(
    String listingId,
    CollabReportInput input, {
    required String clientRequestId,
  }) async {
    reportCalls++;
    return const Result<void>.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
