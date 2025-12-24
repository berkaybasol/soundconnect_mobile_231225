import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../entities/resend_code_result.dart';

class ResendCodeUseCase {
  final AuthRepository _repository;

  ResendCodeUseCase(this._repository);

  Future<Result<ResendCodeResult>> call({required String email}) {
    return _repository.resendCode(email: email);
  }
}
