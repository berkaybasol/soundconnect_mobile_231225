class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final String rePassword;
  final String role;

  const RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    required this.rePassword,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
      'rePassword': rePassword,
      'role': role,
    };
  }
}
