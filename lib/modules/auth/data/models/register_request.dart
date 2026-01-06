class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final String rePassword;
  final String role;
  final String? venueName;
  final String? venueAddress;
  final String? phone;
  final String? cityId;
  final String? districtId;
  final String? neighborhoodId;

  const RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    required this.rePassword,
    required this.role,
    this.venueName,
    this.venueAddress,
    this.phone,
    this.cityId,
    this.districtId,
    this.neighborhoodId,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'username': username,
      'email': email,
      'password': password,
      'rePassword': rePassword,
      'role': role,
    };
    if (venueName != null) data['venueName'] = venueName;
    if (venueAddress != null) data['venueAddress'] = venueAddress;
    if (phone != null) data['phone'] = phone;
    if (cityId != null) data['cityId'] = cityId;
    if (districtId != null) data['districtId'] = districtId;
    if (neighborhoodId != null) data['neighborhoodId'] = neighborhoodId;
    return data;
  }
}
