import 'business_name_policy.dart';
import 'studio_registration_policy.dart';

class BusinessRegistrationDetails {
  BusinessRegistrationDetails({
    required this.isStudio,
    required String name,
    required String address,
    required String phone,
    required this.cityId,
    required this.districtId,
    required this.neighborhoodId,
  }) : name = BusinessNamePolicy.normalize(name),
       address = address.trim(),
       phone = isStudio
           ? StudioRegistrationPolicy.normalizePhone(phone)
           : phone.trim();

  final bool isStudio;
  final String name;
  final String address;
  final String phone;
  final String? cityId;
  final String? districtId;
  final String? neighborhoodId;

  String? get validationMessage {
    final hasLocation =
        cityId?.isNotEmpty == true &&
        districtId?.isNotEmpty == true &&
        neighborhoodId?.isNotEmpty == true;
    if (isStudio) {
      return StudioRegistrationPolicy.validationMessage(
            studioName: name,
            studioAddress: address,
            phone: phone,
          ) ??
          (hasLocation ? null : 'Şehir, ilçe ve mahalle seçimini tamamla.');
    }
    return name.isEmpty || address.isEmpty || phone.isEmpty || !hasLocation
        ? 'Şehir, ilçe, mahalle ve Açık Adres dahil mekan bilgilerini eksiksiz doldur.'
        : null;
  }

  String? get googleValidationMessage {
    final common = validationMessage;
    if (common != null || isStudio) return common;
    if (name.length > 100) return 'Mekân adı en fazla 100 karakter olabilir.';
    if (address.length > 255)
      return 'Açık adres en fazla 255 karakter olabilir.';
    if (phone.length < 10 || phone.length > 15)
      return 'Telefon 10 ile 15 karakter arasında olmalı.';
    return null;
  }

  Map<String, dynamic> toJson() => {
    if (isStudio) ...{
      'studioName': name,
      'studioAddress': address,
      'studioPhone': phone,
    } else ...{
      'venueName': name,
      'venueAddress': address,
      'phone': phone,
    },
    'cityId': cityId,
    'districtId': districtId,
    'neighborhoodId': neighborhoodId,
  };
}
