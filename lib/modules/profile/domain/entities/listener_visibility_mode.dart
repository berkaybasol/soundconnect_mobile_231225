enum ListenerVisibilityMode {
  standard('STANDARD'),
  ghost('GHOST');

  const ListenerVisibilityMode(this.wireValue);

  final String wireValue;

  bool get isGhost => this == ListenerVisibilityMode.ghost;

  static ListenerVisibilityMode fromWire(
    Object? value, {
    bool allowMissingStandard = false,
  }) {
    if (value == null && allowMissingStandard) {
      return ListenerVisibilityMode.standard;
    }
    if (value is! String) {
      throw const FormatException('visibilityMode must be a string');
    }

    return switch (value.trim().toUpperCase()) {
      'STANDARD' => ListenerVisibilityMode.standard,
      'GHOST' => ListenerVisibilityMode.ghost,
      _ => throw FormatException(
        'Unsupported listener visibility mode: $value',
      ),
    };
  }
}
