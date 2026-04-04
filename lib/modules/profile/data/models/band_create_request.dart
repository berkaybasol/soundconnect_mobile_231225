class BandCreateRequest {
  final String name;
  final String? description;

  const BandCreateRequest({
    required this.name,
    this.description,
  });

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{'name': name.trim()};
    final normalizedDescription = description?.trim();
    if (normalizedDescription != null && normalizedDescription.isNotEmpty) {
      payload['description'] = normalizedDescription;
    }
    return payload;
  }
}
