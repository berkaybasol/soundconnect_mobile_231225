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
    String? venueName,
    String? venueAddress,
    String? phone,
    String? cityId,
    String? districtId,
    String? neighborhoodId,
  }) {
    return _repository.register(
      username: username,
      email: email,
      password: password,
      rePassword: rePassword,
      role: role,
      venueName: venueName,
      venueAddress: venueAddress,
      phone: phone,
      cityId: cityId,
      districtId: districtId,
      neighborhoodId: neighborhoodId,
    );
  }
}
