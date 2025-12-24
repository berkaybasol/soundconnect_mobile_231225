import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../entities/login_result.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Result<LoginResult>> call({
    required String username,
    required String password,
  }) {
    return _repository.login(username: username, password: password);
  }
}
