import '../../../../core/error/result.dart';
import '../auth_repository.dart';

class VerifyCodeUseCase {
  final AuthRepository _repository;

  VerifyCodeUseCase(this._repository);

  Future<Result<void>> call({
    required String email,
    required String code,
  }) {
    return _repository.verifyCode(email: email, code: code);
  }
}
