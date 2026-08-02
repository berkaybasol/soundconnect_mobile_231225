import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/username_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/usecases/update_username_usecase.dart';

import 'support/auth_widget_test_support.dart';

void main() {
  group('UsernamePolicy', () {
    test('trims and lowercases usernames deterministically', () {
      expect(UsernamePolicy.normalize('  BeRKay  '), 'berkay');
      expect(UsernamePolicy.normalize('\tMixed_CASE\n'), 'mixed_case');
      expect(UsernamePolicy.normalize('IUSER'), 'iuser');
      expect(UsernamePolicy.normalize('İUSER'), 'iuser');
      expect(UsernamePolicy.normalize('ΟΣ'), 'οσ');
      expect(UsernamePolicy.normalize('ΣΟΣ'), 'σοσ');
      expect(UsernamePolicy.normalize('ẞ'), 'ß');
      expect(UsernamePolicy.normalize('\u{10400}USER'), '\u{10428}user');
    });

    test('strips the backend whitespace set only at boundaries', () {
      expect(
        UsernamePolicy.normalize(
          '\t\u00A0\u2003\uFEFFBeRKay\uFEFF\u2003\u00A0\t',
        ),
        'berkay',
      );
      expect(
        UsernamePolicy.normalize('A\u00A0B\u2003C\uFEFFD'),
        'a\u00A0b\u2003c\uFEFFd',
      );
    });

    test('preserves the existing 3 to 30 character boundary', () {
      expect(UsernamePolicy.isValid('ab'), isFalse);
      expect(UsernamePolicy.isValid('abc'), isTrue);
      expect(UsernamePolicy.isValid(List.filled(30, 'A').join()), isTrue);
      expect(UsernamePolicy.isValid(List.filled(31, 'A').join()), isFalse);
      expect(UsernamePolicy.isValid(List.filled(15, '🎸').join()), isTrue);
      expect(UsernamePolicy.isValid(List.filled(16, '🎸').join()), isFalse);
    });
  });

  test(
    'UpdateUsernameUseCase normalizes before reaching the repository',
    () async {
      final repository = RecordingAuthRepository()
        ..updateUsernameResult = const Result.success('berkay');

      final result = await UpdateUsernameUseCase(repository)(
        username: '  BeRKay  ',
      );

      expect(result.data, 'berkay');
      expect(repository.lastUpdatedUsername, 'berkay');
    },
  );
}
