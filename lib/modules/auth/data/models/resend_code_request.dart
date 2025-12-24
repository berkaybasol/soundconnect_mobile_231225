class ResendCodeRequest {
  final String email;

  const ResendCodeRequest({required this.email});

  Map<String, dynamic> toJson() {
    return {'email': email};
  }
}
