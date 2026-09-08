import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/domain/artist_venue_connection_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/artist_venue/presentation/cubit/artist_venue_connections_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_venue_models.dart';

void main() {
  test('latest accepted-venue read wins when older requests finish last', () async {
    final repository = _Repository();
    final cubit = ArtistVenueConnectionsCubit(repository);
    addTearDown(cubit.close);
    final old = cubit.loadAcceptedVenues('old');
    final latest = cubit.loadAcceptedVenues('new');
    repository.reads[1].complete(Result.success([_venue('new')]));
    await latest;
    repository.reads[0].complete(Result.success([_venue('old')]));
    await old;
    expect(cubit.state.venues.single.venueId, 'new');
  });

  test('switching profile clears the previous profile connections while loading', () async {
    final repository = _Repository();
    final cubit = ArtistVenueConnectionsCubit(repository);
    addTearDown(cubit.close);
    final old = cubit.loadAcceptedVenues('old');
    repository.reads[0].complete(Result.success([_venue('old')]));
    await old;
    final latest = cubit.loadAcceptedVenues('new');
    expect(cubit.state.venues, isEmpty);
    repository.reads[1].complete(const Result.success([]));
    await latest;
  });

  test('completion after screen disposal does not emit into a closed cubit', () async {
    final repository = _Repository();
    final cubit = ArtistVenueConnectionsCubit(repository);
    final loading = cubit.loadAcceptedVenues('profile');
    await cubit.close();
    repository.reads.single.complete(Result.success([_venue('venue')]));
    await expectLater(loading, completes);
  });
}

VenueConnection _venue(String id) => VenueConnection(requestId: id, venueId: id, venueName: id);

class _Repository extends Fake implements ArtistVenueConnectionRepository {
  final reads = <Completer<Result<List<VenueConnection>>>>[];
  @override
  Future<Result<List<VenueConnection>>> getVenueConnectionsByStatus(String musicianProfileId, {required String status}) {
    final read = Completer<Result<List<VenueConnection>>>();
    reads.add(read);
    return read.future;
  }
}
