import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../entities/register_result.dart';

class RegisterUseCase {
  final AuthRepository _repository;

  RegisterUseCase(this._repository);

  Future<Result<RegisterResult>> call({
    required String username,
    required String email,
    required String password,
    required String rePassword,
    required String role,
  }) {
    return _repository.register(
      username: username,
      email: email,
      password: password,
      rePassword: rePassword,
      role: role,
    );
  }
}
