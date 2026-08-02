import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../password_reset_identifier_policy.dart';

class ResetPasswordUseCase {
  final AuthRepository _repository;

  ResetPasswordUseCase(this._repository);

  Future<Result<void>> call({
    required String identifier,
    required String code,
    required String password,
    required String rePassword,
  }) {
    return _repository.resetPassword(
      identifier: PasswordResetIdentifierPolicy.normalize(identifier),
      code: code.trim(),
      password: password,
      rePassword: rePassword,
    );
  }
}
