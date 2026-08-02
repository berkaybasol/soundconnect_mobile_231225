import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../entities/password_reset_account.dart';
import '../password_reset_identifier_policy.dart';

class ResolvePasswordResetAccountUseCase {
  const ResolvePasswordResetAccountUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<PasswordResetAccount>> call({required String identifier}) {
    return _repository.resolvePasswordResetAccount(
      identifier: PasswordResetIdentifierPolicy.normalize(identifier),
    );
  }
}
