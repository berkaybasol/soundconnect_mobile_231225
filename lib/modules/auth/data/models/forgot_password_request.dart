class ForgotPasswordRequest {
  final String identifier;

  const ForgotPasswordRequest({required this.identifier});

  Map<String, dynamic> toJson() => <String, dynamic>{'identifier': identifier};
}
