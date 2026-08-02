import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../username_policy.dart';

class UpdateUsernameUseCase {
  final AuthRepository _repository;

  UpdateUsernameUseCase(this._repository);

  Future<Result<String>> call({required String username}) {
    return _repository.updateUsername(
      username: UsernamePolicy.normalize(username),
    );
  }
}
