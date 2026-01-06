import '../../domain/entities/neighborhood.dart';

class NeighborhoodModel {
  final String id;
  final String name;
  final String districtId;

  const NeighborhoodModel({
    required this.id,
    required this.name,
    required this.districtId,
  });

  factory NeighborhoodModel.fromJson(Map<String, dynamic> json) {
    return NeighborhoodModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      districtId: json['districtId'] as String? ?? '',
    );
  }

  Neighborhood toEntity() =>
      Neighborhood(id: id, name: name, districtId: districtId);
}
