import '../../../../core/error/result.dart';
import '../auth_repository.dart';
import '../business_name_policy.dart';
import '../entities/register_result.dart';
import '../username_policy.dart';

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
    String? studioName,
    String? studioAddress,
    String? studioPhone,
  }) {
    return _repository.register(
      username: UsernamePolicy.normalize(username),
      email: email,
      password: password,
      rePassword: rePassword,
      role: role,
      venueName: venueName == null
          ? null
          : BusinessNamePolicy.normalize(venueName),
      venueAddress: venueAddress,
      phone: phone,
      cityId: cityId,
      districtId: districtId,
      neighborhoodId: neighborhoodId,
      studioName: studioName == null
          ? null
          : BusinessNamePolicy.normalize(studioName),
      studioAddress: studioAddress,
      studioPhone: studioPhone,
    );
  }
}
