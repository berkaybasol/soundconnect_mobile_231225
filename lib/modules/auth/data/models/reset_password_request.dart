class ResetPasswordRequest {
  final String identifier;
  final String code;
  final String password;
  final String rePassword;

  const ResetPasswordRequest({
    required this.identifier,
    required this.code,
    required this.password,
    required this.rePassword,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'identifier': identifier,
    'code': code,
    'password': password,
    'rePassword': rePassword,
  };
}
