import '../../domain/entities/instrument.dart';

class InstrumentModel extends Instrument {
  const InstrumentModel({
    required super.id,
    required super.name,
  });

  factory InstrumentModel.fromJson(Map<String, dynamic> json) {
    return InstrumentModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
