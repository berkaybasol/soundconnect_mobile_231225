import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/band_member_summary_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/band_profile_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_member_title_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_representative_contact_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';

void main() {
  group('band member display title is not authority', () {
    test(
      'legacy entity has no display title and starts at title version zero',
      () {
        const member = BandMemberSummary(
          userId: 'member-user',
          profileId: 'member-profile',
          username: 'aedrum',
          profilePictureUrl: null,
          role: 'MEMBER',
          status: 'ACTIVE',
        );
        expect(member.memberTitle, isNull);
        expect(member.displayTitle, isNull);
        expect(member.titleVersion, 0);
        expect(member.isFounder, isFalse);
      },
    );

    for (final title in [null, '', '  ']) {
      test(
        'empty custom title $title never falls back to an authority label',
        () {
          final member = _member(role: 'FOUNDER', title: title);
          expect(member.displayTitle, isNull);
          expect(member.isFounder, isTrue);
          expect(member.localizedRoleLabel, 'Kurucu');
        },
      );
    }

    test('title is trimmed for display independently of authority role', () {
      final member = _member(title: '  Davul  ');
      expect(member.displayTitle, 'Davul');
      expect(member.roleCode, 'MEMBER');
      expect(member.localizedRoleLabel, 'Üye');
      expect(member.isFounder, isFalse);
    });

    for (final title in ['Kurucu', 'FOUNDER', 'Menajer', 'ADMIN']) {
      test(
        'custom title $title never grants founder or representative status',
        () {
          final member = _member(title: title);
          expect(member.isFounder, isFalse);
          expect(member.roleCode, 'MEMBER');
          expect(BandRepresentativeContactPolicy.resolve([member]), isNull);
        },
      );
    }

    test('custom instrument title never removes real founder authority', () {
      final member = _member(role: ' founder ', title: 'Bas gitar');
      expect(member.displayTitle, 'Bas gitar');
      expect(member.isFounder, isTrue);
      expect(BandRepresentativeContactPolicy.resolve([member]), same(member));
    });

    test('title copy preserves identity, avatar, membership and authority', () {
      final original = _member(role: 'FOUNDER', title: 'Gitar', version: 3);
      final changed = original.copyWithTitle(
        memberTitle: 'Vokal',
        titleVersion: 4,
      );
      expect(changed, isNot(same(original)));
      expect(changed.memberTitle, 'Vokal');
      expect(changed.titleVersion, 4);
      expect(changed.userId, original.userId);
      expect(changed.profileId, original.profileId);
      expect(changed.username, original.username);
      expect(changed.profilePictureUrl, original.profilePictureUrl);
      expect(changed.role, original.role);
      expect(changed.status, original.status);
      expect(changed.isFounder, isTrue);
      expect(original.memberTitle, 'Gitar');
      expect(original.titleVersion, 3);
    });

    test('explicit null copy clears title while keeping latest version', () {
      final cleared = _member(
        title: 'Davul',
        version: 8,
      ).copyWithTitle(memberTitle: null, titleVersion: 9);
      expect(cleared.memberTitle, isNull);
      expect(cleared.displayTitle, isNull);
      expect(cleared.titleVersion, 9);
      expect(cleared.isFounder, isFalse);
    });
  });

  group('band member title JSON contract', () {
    test('legacy payload remains readable without title fields', () {
      final json = _json()
        ..remove('memberTitle')
        ..remove('titleVersion');
      final member = BandMemberSummaryModel.fromJson(json);
      expect(member.memberTitle, isNull);
      expect(member.displayTitle, isNull);
      expect(member.titleVersion, 0);
      expect(member.userId, 'member-user');
    });

    test(
      'new title fields are parsed without overwriting role or profile ID',
      () {
        final member = BandMemberSummaryModel.fromJson(
          _json(title: '  Davul  ', version: 7),
        );
        expect(member.displayTitle, 'Davul');
        expect(member.titleVersion, 7);
        expect(member.role, 'MEMBER');
        expect(member.isFounder, isFalse);
        expect(member.profileId, 'member-profile');
        expect(member.profilePictureUrl, 'https://example.test/avatar.jpg');
      },
    );

    test('null title clears display but retains optimistic version', () {
      final member = BandMemberSummaryModel.fromJson(
        _json(title: null, version: 4),
      );
      expect(member.memberTitle, isNull);
      expect(member.titleVersion, 4);
    });

    for (final invalid in <Object>[
      42,
      true,
      <String>['Davul'],
      <String, String>{'name': 'Davul'},
    ]) {
      test('nonstring JSON title $invalid fails parsing', () {
        final json = _json()..['memberTitle'] = invalid;
        expect(
          () => BandMemberSummaryModel.fromJson(json),
          throwsFormatException,
        );
      });
    }

    for (final invalid in <Object>[
      -1,
      1.5,
      '2',
      true,
      <int>[2],
    ]) {
      test('malformed JSON title version $invalid fails parsing', () {
        final json = _json()..['titleVersion'] = invalid;
        expect(
          () => BandMemberSummaryModel.fromJson(json),
          throwsFormatException,
        );
      });
    }

    for (final title in ['x' * 21, 'Davul\nVokal', 'Davul\u202e']) {
      test('invalid server title is not silently displayed ($title)', () {
        expect(
          () => BandMemberSummaryModel.fromJson(_json(title: title)),
          throwsFormatException,
        );
      });
    }

    test('band profile decoder preserves every member title and version', () {
      final band = BandProfileModel.fromJson({
        'id': 'band',
        'name': 'Şahbaz',
        'members': [
          _json(title: 'Gitar', version: 3)..['role'] = 'FOUNDER',
          _json(title: 'Davul', version: 8)..['userId'] = 'another-member',
        ],
      });
      expect(band.members.map((member) => member.displayTitle), [
        'Gitar',
        'Davul',
      ]);
      expect(band.members.map((member) => member.titleVersion), [3, 8]);
      expect(band.members.first.isFounder, isTrue);
      expect(band.members.last.isFounder, isFalse);
    });
  });

  group('band member title Unicode and input policy', () {
    test('declared limits match the backend contract', () {
      expect(BandMemberTitlePolicy.maxCharacters, 20);
      expect(BandMemberTitlePolicy.maxCodePoints, 256);
    });

    for (final title in <String?>[null, '', '   ']) {
      test('empty title $title is a valid clear command', () {
        expect(BandMemberTitlePolicy.normalize(title), isNull);
        expect(BandMemberTitlePolicy.validationMessage(title), isNull);
      });
    }

    test(
      'normalizes only outer whitespace, preserving intentional internal text',
      () {
        expect(
          BandMemberTitlePolicy.normalize('  Vokal & Gitar  '),
          'Vokal & Gitar',
        );
        expect(BandMemberTitlePolicy.normalize('Çok  sesli'), 'Çok  sesli');
      },
    );

    for (final title in [
      'x' * 20,
      'Ş' * 20,
      'a\u0301' * 20,
      '🥁' * 20,
      '👨‍👩‍👧‍👦' * 20,
      '🇹🇷' * 20,
      'گیتار\u200cزن',
      'Gitar\u200dVokal',
    ]) {
      test('valid grapheme-limited Unicode title ${title.runes.toList()}', () {
        expect(BandMemberTitlePolicy.validationMessage(title), isNull);
      });
    }

    for (final title in [
      'x' * 21,
      'a\u0301' * 21,
      '🥁' * 21,
      '👨‍👩‍👧‍👦' * 21,
    ]) {
      test(
        'twenty-one graphemes are rejected (${title.runes.length} code points)',
        () {
          expect(BandMemberTitlePolicy.validationMessage(title), isNotNull);
        },
      );
    }

    test('raw code point ceiling also applies to a single large grapheme', () {
      final boundary = 'a${'\u0301' * 255}';
      expect(boundary.runes.length, 256);
      expect(BandMemberTitlePolicy.validationMessage(boundary), isNull);
      expect(
        BandMemberTitlePolicy.validationMessage('$boundary\u0301'),
        isNotNull,
      );
    });

    test('raw limit is checked before trimming whitespace', () {
      expect(
        BandMemberTitlePolicy.validationMessage('${' ' * 256}a'),
        isNotNull,
      );
    });

    for (final separator in [
      '\n',
      '\r',
      '\t',
      '\u0000',
      '\u007f',
      '\u0085',
      '\u2028',
      '\u2029',
    ]) {
      test('single-line title rejects control ${separator.codeUnitAt(0)}', () {
        expect(
          BandMemberTitlePolicy.validationMessage('Davul${separator}Vokal'),
          isNotNull,
        );
        expect(
          BandMemberTitlePolicy.validationMessage('${separator}Davul'),
          isNotNull,
        );
        expect(
          BandMemberTitlePolicy.validationMessage('Davul$separator'),
          isNotNull,
        );
      });
    }

    for (final format in [
      '\u00ad',
      '\u200b',
      '\u200e',
      '\u202e',
      '\u2066',
      '\ufeff',
    ]) {
      test('nonjoining format control ${format.codeUnitAt(0)} is rejected', () {
        expect(
          BandMemberTitlePolicy.validationMessage('Davul$format'),
          isNotNull,
        );
      });
    }

    for (final invisible in [
      '\u200c',
      '\u200d',
      '\u0301',
      ' \u200c\u200d\u0301 ',
    ]) {
      test('invisible title ${invisible.runes.toList()} is rejected', () {
        expect(BandMemberTitlePolicy.validationMessage(invisible), isNotNull);
      });
    }

    for (final title in ['123', '#1', '🎸', 'A\u0301']) {
      test(
        'visible number, punctuation, symbol or letter is allowed ($title)',
        () {
          expect(BandMemberTitlePolicy.validationMessage(title), isNull);
        },
      );
    }
  });

  group('member title repository request contract', () {
    test(
      'PATCH sends only display title and version with account fence',
      () async {
        final api = _TitleApi();
        final result = await BandRepositoryImpl(api).updateMemberTitle(
          bandId: 'band',
          userId: 'member-user',
          memberTitle: '  Davul  ',
          expectedTitleVersion: 2,
          expectedSessionKey: 'founder-user',
        );
        expect(result.isSuccess, isTrue);
        expect(api.calls, 1);
        expect(api.method, ApiHttpMethod.patch);
        expect(api.path, '/api/v1/user/bands/band/members/member-user/title');
        expect(api.body, {'memberTitle': 'Davul', 'expectedTitleVersion': 2});
        expect(api.context?.expectedSessionKey, 'founder-user');
        expect(result.data?.memberTitle, 'Davul');
        expect(result.data?.titleVersion, 3);
        expect(result.data?.role, 'MEMBER');
      },
    );

    for (final title in <String?>[null, '', '  ']) {
      test(
        'clear $title explicitly sends null instead of omitting field',
        () async {
          final api = _TitleApi()..response = _json(title: null, version: 3);
          final result = await BandRepositoryImpl(api).updateMemberTitle(
            bandId: 'band',
            userId: 'member-user',
            memberTitle: title,
            expectedTitleVersion: 2,
            expectedSessionKey: 'founder-user',
          );
          expect(result.isSuccess, isTrue);
          expect(api.body, {'memberTitle': null, 'expectedTitleVersion': 2});
          expect(result.data?.displayTitle, isNull);
        },
      );
    }

    for (final title in [
      'x' * 21,
      'Davul\nVokal',
      'Davul\u202e',
      'a${'\u0301' * 256}',
    ]) {
      test(
        'invalid title does not dispatch a network command ($title)',
        () async {
          final api = _TitleApi();
          final result = await BandRepositoryImpl(api).updateMemberTitle(
            bandId: 'band',
            userId: 'member-user',
            memberTitle: title,
            expectedTitleVersion: 2,
            expectedSessionKey: 'founder-user',
          );
          expect(result.isSuccess, isFalse);
          expect(api.calls, 0);
        },
      );
    }

    for (final invalid in [
      (band: '', user: 'member-user', version: 2),
      (band: 'band', user: ' ', version: 2),
      (band: 'band', user: 'member-user', version: -1),
      (band: 'band/other', user: 'member-user', version: 2),
      (band: 'band', user: '../other', version: 2),
      (band: 'band?all=true', user: 'member-user', version: 2),
      (band: 'band', user: 'member-user#fragment', version: 2),
      (band: 'band', user: 'member-user', version: 0x7fffffffffffffff),
    ]) {
      test(
        'invalid command identity/version $invalid fails before dispatch',
        () async {
          final api = _TitleApi();
          final result = await BandRepositoryImpl(api).updateMemberTitle(
            bandId: invalid.band,
            userId: invalid.user,
            memberTitle: 'Davul',
            expectedTitleVersion: invalid.version,
            expectedSessionKey: 'founder-user',
          );
          expect(result.isSuccess, isFalse);
          expect(api.calls, 0);
        },
      );
    }

    test(
      'empty expected account is rejected before transport dispatch',
      () async {
        final api = _TitleApi();
        final result = await BandRepositoryImpl(api).updateMemberTitle(
          bandId: 'band',
          userId: 'member-user',
          memberTitle: 'Davul',
          expectedTitleVersion: 2,
          expectedSessionKey: '  ',
        );
        expect(result.isSuccess, isFalse);
        expect(api.calls, 0);
      },
    );

    test(
      'canonical IDs and account fence trim only outer whitespace',
      () async {
        final api = _TitleApi();
        final result = await BandRepositoryImpl(api).updateMemberTitle(
          bandId: ' band ',
          userId: ' member-user ',
          memberTitle: 'Davul',
          expectedTitleVersion: 2,
          expectedSessionKey: ' founder-user ',
        );
        expect(result.isSuccess, isTrue);
        expect(api.path, '/api/v1/user/bands/band/members/member-user/title');
        expect(api.context?.expectedSessionKey, 'founder-user');
      },
    );

    for (final code in ['9214', '9215', '9216', '403', 'session_changed']) {
      test(
        'server/session error $code is preserved for caller recovery',
        () async {
          final error = AppError(
            code: code,
            message: 'Title could not be changed',
          );
          final api = _TitleApi()..failure = ApiException(error);
          final result = await BandRepositoryImpl(api).updateMemberTitle(
            bandId: 'band',
            userId: 'member-user',
            memberTitle: 'Davul',
            expectedTitleVersion: 2,
            expectedSessionKey: 'founder-user',
          );
          expect(result.isSuccess, isFalse);
          expect(result.error, same(error));
          expect(api.calls, 1);
        },
      );
    }

    test(
      'unsupported fenced transport cannot silently issue an unfenced PATCH',
      () async {
        final api = _UnfencedApi();
        final result = await BandRepositoryImpl(api).updateMemberTitle(
          bandId: 'band',
          userId: 'member-user',
          memberTitle: 'Davul',
          expectedTitleVersion: 2,
          expectedSessionKey: 'founder-user',
        );
        expect(result.isSuccess, isFalse);
        expect(api.patchCalls, 0);
      },
    );

    test('unexpected transport exception is represented as failure', () async {
      final api = _TitleApi()..failure = StateError('offline');
      final result = await BandRepositoryImpl(api).updateMemberTitle(
        bandId: 'band',
        userId: 'member-user',
        memberTitle: 'Davul',
        expectedTitleVersion: 2,
        expectedSessionKey: 'founder-user',
      );
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    for (final response in <Object?>[
      null,
      <Object>[],
      _json()..['userId'] = 'wrong-member',
      _json()..['status'] = 'LEFT',
      _json()..['status'] = 'PENDING',
      _json()..['titleVersion'] = 1,
      _json()..['titleVersion'] = -1,
      _json()..['titleVersion'] = 4,
      _json()..['titleVersion'] = null,
      _json()..remove('titleVersion'),
      _json()..remove('memberTitle'),
      _json()..['role'] = ' ',
      _json()..['memberTitle'] = 42,
    ]) {
      test(
        'invalid title mutation response fails closed ($response)',
        () async {
          final api = _TitleApi()..response = response;
          final result = await BandRepositoryImpl(api).updateMemberTitle(
            bandId: 'band',
            userId: 'member-user',
            memberTitle: 'Davul',
            expectedTitleVersion: 2,
            expectedSessionKey: 'founder-user',
          );
          expect(result.isSuccess, isFalse);
          expect(result.data, isNull);
        },
      );
    }

    test(
      'same-version idempotent unchanged title response is accepted',
      () async {
        final api = _TitleApi()..response = _json(title: 'Davul', version: 2);
        final result = await BandRepositoryImpl(api).updateMemberTitle(
          bandId: 'band',
          userId: 'member-user',
          memberTitle: 'Davul',
          expectedTitleVersion: 2,
          expectedSessionKey: 'founder-user',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data?.titleVersion, 2);
      },
    );
  });
}

BandMemberSummary _member({
  String role = 'MEMBER',
  String? title,
  int version = 0,
}) => BandMemberSummary(
  userId: 'member-user',
  profileId: 'member-profile',
  username: 'aedrum',
  profilePictureUrl: 'https://example.test/avatar.jpg',
  role: role,
  status: 'ACTIVE',
  memberTitle: title,
  titleVersion: version,
);

Map<String, dynamic> _json({String? title = 'Davul', int version = 3}) => {
  'userId': 'member-user',
  'profileId': 'member-profile',
  'username': 'aedrum',
  'profilePictureUrl': 'https://example.test/avatar.jpg',
  'role': 'MEMBER',
  'status': 'ACTIVE',
  'memberTitle': title,
  'titleVersion': version,
};

class _TitleApi extends ApiClient {
  int calls = 0;
  ApiHttpMethod? method;
  String? path;
  Object? body;
  ApiRequestContext? context;
  Object? response = _json();
  Object? failure;

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    this.method = method;
    this.path = path;
    this.body = body;
    context = requestContext;
    if (failure case final error?) throw error;
    return decoder!(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnfencedApi extends ApiClient {
  int patchCalls = 0;

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    patchCalls++;
    return decoder!(_json());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
