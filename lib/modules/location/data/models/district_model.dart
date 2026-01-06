import '../../domain/entities/district.dart';

class DistrictModel {
  final String id;
  final String name;
  final String cityId;

  const DistrictModel({
    required this.id,
    required this.name,
    required this.cityId,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cityId: json['cityId'] as String? ?? '',
    );
  }

  District toEntity() => District(id: id, name: name, cityId: cityId);
}
