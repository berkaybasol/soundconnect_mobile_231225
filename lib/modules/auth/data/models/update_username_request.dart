class UpdateUsernameRequest {
  final String username;

  const UpdateUsernameRequest({required this.username});

  Map<String, dynamic> toJson() => <String, dynamic>{'username': username};
}
