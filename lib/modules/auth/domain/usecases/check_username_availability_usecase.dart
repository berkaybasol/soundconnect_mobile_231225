import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../entities/username_availability.dart';
import '../username_policy.dart';

class CheckUsernameAvailabilityUseCase {
  const CheckUsernameAvailabilityUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<UsernameAvailability>> call({required String username}) {
    return _repository.checkUsernameAvailability(
      username: UsernamePolicy.normalize(username),
    );
  }
}
