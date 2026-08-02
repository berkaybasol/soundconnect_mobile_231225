class UsernameAvailabilityRequest {
  const UsernameAvailabilityRequest({required this.username});

  final String username;

  Map<String, dynamic> toJson() => {'username': username};
}
