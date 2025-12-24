class VerifyCodeRequest {
  final String email;
  final String code;

  const VerifyCodeRequest({
    required this.email,
    required this.code,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'code': code,
    };
  }
}
