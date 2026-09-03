import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../entities/verify_code_result.dart';

class VerifyCodeUseCase {
  final AuthRepository _repository;

  VerifyCodeUseCase(this._repository);

  Future<Result<VerifyCodeResult>> call({
    required String email,
    required String code,
  }) {
    return _repository.verifyCode(email: email, code: code);
  }
}
