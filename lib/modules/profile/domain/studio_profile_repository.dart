import '../../../core/error/result.dart';
import 'entities/studio_profile.dart';

abstract class StudioProfileRepository {
  Future<Result<StudioProfile>> getMyProfile();

  Future<Result<StudioProfile>> getPublicProfile(String profileId);

  Future<Result<StudioProfile>> updateMyProfile(StudioProfileSaveRequest request);
}

class StudioProfileSaveRequest {
  final String? name;
  final String? description;
  final String? profilePictureMediaId;
  final String? address;
  final String? phone;
  final String? website;
  final List<String>? facilities;
  final String? instagramUrl;
  final String? youtubeUrl;

  const StudioProfileSaveRequest({
    this.name,
    this.description,
    this.profilePictureMediaId,
    this.address,
    this.phone,
    this.website,
    this.facilities,
    this.instagramUrl,
    this.youtubeUrl,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'profilePicture': profilePictureMediaId,
      'address': address,
      'phone': phone,
      'website': website,
      'facilities': facilities,
      'instagramUrl': instagramUrl,
      'youtubeUrl': youtubeUrl,
    }..removeWhere((_, value) => value == null);
  }
}
