import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../password_reset_identifier_policy.dart';

class RequestPasswordResetUseCase {
  final AuthRepository _repository;

  RequestPasswordResetUseCase(this._repository);

  Future<Result<void>> call({required String identifier}) {
    return _repository.requestPasswordReset(
      identifier: PasswordResetIdentifierPolicy.normalize(identifier),
    );
  }
}
