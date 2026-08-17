import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/utils/turkish_alphabetical.dart';

void main() {
  test('sorts Turkish letters and leading numbers naturally', () {
    final names = <String>[
      'Üsküdar',
      '100. Yıl',
      'İstanbul',
      'İzmir',
      'Iğdır',
      'Isparta',
      'Şişli',
      'Sivas',
      '10 Ekim',
      'Çankaya',
      'Ceyhan',
      'Ödemiş',
      'Osmangazi',
      'Gölbaşı',
      'Gazipaşa',
      'Ğazi',
      'Ordu',
      'Ağrı',
      'Uşak',
      '2 Eylül',
      'Adana',
    ]..sort(compareTurkishAlphabetical);

    expect(names, <String>[
      '2 Eylül',
      '10 Ekim',
      '100. Yıl',
      'Adana',
      'Ağrı',
      'Ceyhan',
      'Çankaya',
      'Gazipaşa',
      'Gölbaşı',
      'Ğazi',
      'Iğdır',
      'Isparta',
      'İstanbul',
      'İzmir',
      'Ordu',
      'Osmangazi',
      'Ödemiş',
      'Sivas',
      'Şişli',
      'Uşak',
      'Üsküdar',
    ]);
  });
}
