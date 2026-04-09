enum SetlistKey {
  cMaj('C_MAJ', 'C Maj'),
  cMin('C_MIN', 'C Min'),
  cSharpMaj('C_SHARP_MAJ', 'C# Maj'),
  cSharpMin('C_SHARP_MIN', 'C# Min'),
  dMaj('D_MAJ', 'D Maj'),
  dMin('D_MIN', 'D Min'),
  dSharpMaj('D_SHARP_MAJ', 'D# Maj'),
  dSharpMin('D_SHARP_MIN', 'D# Min'),
  eMaj('E_MAJ', 'E Maj'),
  eMin('E_MIN', 'E Min'),
  fMaj('F_MAJ', 'F Maj'),
  fMin('F_MIN', 'F Min'),
  fSharpMaj('F_SHARP_MAJ', 'F# Maj'),
  fSharpMin('F_SHARP_MIN', 'F# Min'),
  gMaj('G_MAJ', 'G Maj'),
  gMin('G_MIN', 'G Min'),
  gSharpMaj('G_SHARP_MAJ', 'G# Maj'),
  gSharpMin('G_SHARP_MIN', 'G# Min'),
  aMaj('A_MAJ', 'A Maj'),
  aMin('A_MIN', 'A Min'),
  aSharpMaj('A_SHARP_MAJ', 'A# Maj'),
  aSharpMin('A_SHARP_MIN', 'A# Min'),
  bMaj('B_MAJ', 'B Maj'),
  bMin('B_MIN', 'B Min'),
  original('ORIGINAL', 'Original');

  const SetlistKey(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static SetlistKey fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toUpperCase();
    for (final key in values) {
      if (key.apiValue == normalized) return key;
    }
    return SetlistKey.original;
  }
}
