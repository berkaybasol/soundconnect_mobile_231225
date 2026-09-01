import '../../domain/entities/table_group_venue_option.dart';

class TableGroupVenueOptionModel extends TableGroupVenueOption {
  const TableGroupVenueOptionModel({
    required super.id,
    required super.name,
    required super.profilePictureUrl,
    required super.address,
    required super.cityId,
    required super.cityName,
    required super.districtId,
    required super.districtName,
    required super.neighborhoodId,
    required super.neighborhoodName,
  });

  factory TableGroupVenueOptionModel.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid venue option $key');
      }
      return value.trim();
    }

    String? optionalText(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) {
        throw FormatException('Invalid venue option $key');
      }
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }

    return TableGroupVenueOptionModel(
      id: requiredText('id'),
      name: requiredText('name'),
      profilePictureUrl: optionalText('profilePictureUrl'),
      address: requiredText('address'),
      cityId: requiredText('cityId'),
      cityName: requiredText('cityName'),
      districtId: requiredText('districtId'),
      districtName: requiredText('districtName'),
      neighborhoodId: requiredText('neighborhoodId'),
      neighborhoodName: requiredText('neighborhoodName'),
    );
  }
}
