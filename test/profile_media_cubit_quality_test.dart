import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_media.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/profile_media_state.dart';

void main() {
  test(
    'late media for an old profile cannot replace the selected profile',
    () async {
      final old = Completer<Result<ProfileMedia>>();
      final recent = ProfileMedia(featuredVideo: null, videos: [], audios: []);
      final repository = _MediaRepository(
        (id) => id == 'old' ? old.future : Future.value(Result.success(recent)),
      );
      final cubit = ProfileMediaCubit(repository);
      addTearDown(cubit.close);
      final first = cubit.loadMedia(profileType: 'MUSICIAN', profileId: 'old');
      await cubit.loadMedia(profileType: 'VENUE', profileId: 'current');
      old.complete(const Result.success(_empty));
      await first;
      expect(cubit.state.media, same(recent));
    },
  );

  test(
    'another profile clears cached media and failure is retryable',
    () async {
      final repository = _MediaRepository(
        (_) async => const Result.success(_empty),
      );
      final cubit = ProfileMediaCubit(repository);
      addTearDown(cubit.close);
      await cubit.loadMedia(profileType: 'MUSICIAN', profileId: 'old');
      repository.loader = (_) async => throw StateError('transport');
      final load = cubit.loadMedia(profileType: 'BAND', profileId: 'current');
      expect(cubit.state.media, isNull);
      await load;
      expect(cubit.state.status, ProfileMediaStatus.failure);
      repository.loader = (_) async => const Result.success(_empty);
      await cubit.loadMedia(profileType: 'BAND', profileId: 'current');
      expect(cubit.state.status, ProfileMediaStatus.success);
      expect(cubit.state.error, isNull);
    },
  );

  test(
    'closing the profile while media loads never emits afterwards',
    () async {
      final pending = Completer<Result<ProfileMedia>>();
      final repository = _MediaRepository((_) => pending.future);
      final cubit = ProfileMediaCubit(repository);
      final load = cubit.loadMedia(
        profileType: 'MUSICIAN',
        profileId: 'profile',
      );
      await cubit.close();
      pending.complete(const Result.success(_empty));
      await load;
      await cubit.loadMedia(profileType: 'MUSICIAN', profileId: 'ignored');
      expect(repository.calls, 1);
    },
  );
}

const _empty = ProfileMedia(featuredVideo: null, videos: [], audios: []);

class _MediaRepository implements ProfileMediaRepository {
  _MediaRepository(this.loader);
  Future<Result<ProfileMedia>> Function(String) loader;
  int calls = 0;
  @override
  Future<Result<ProfileMedia>> getProfileMedia({
    required String profileType,
    required String profileId,
  }) {
    calls++;
    return loader(profileId);
  }
}
