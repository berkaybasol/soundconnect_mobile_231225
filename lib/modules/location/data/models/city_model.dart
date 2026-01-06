import '../../domain/entities/city.dart';

class CityModel {
  final String id;
  final String name;

  const CityModel({required this.id, required this.name});

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  City toEntity() => City(id: id, name: name);
}
