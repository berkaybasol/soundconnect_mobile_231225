part of 'studio_profile_screen.dart';

const _backlineQuickFilters = <String>[
  'Tümü',
  'Davul, Bateri & Zil',
  'Gitar Amfileri',
  'Bas Amfileri',
  'Piyano & Klavye',
  'Perküsyon',
];

const _backlineCategories = <_BacklineCategory>[
  _BacklineCategory(
    name: 'Davul, Bateri & Zil',
    icon: Icons.album_outlined,
    assetPath: 'assets/backline_icons/drum-kit.png',
    children: [
      'Davul / Bateri - Akustik Setler',
      'Davul / Bateri - Elektronik Setler',
      'Trampetler (Snare)',
      'Ziller',
      'Davul Aksesuarları - Pedallar',
      'Davul Aksesuarları - Elektronik Padler & Modüller',
      'Davul Aksesuarları - Hardware & Standlar',
      'Davul Aksesuarları - Yedekler & Sarf Malzemeleri',
    ],
  ),
  _BacklineCategory(
    name: 'Gitar Amfileri',
    icon: Icons.speaker_outlined,
    children: [
      'Elektrik Gitar Amfileri - Combo',
      'Elektrik Gitar Amfileri - Kafa',
      'Kabinler - Elektrik Gitar',
      'Akustik Gitar Amfileri',
      'Modelleyiciler & Multi-Efektler',
      'Gitar Pedalları & Footswitchler',
    ],
  ),
  _BacklineCategory(
    name: 'Bas Gitar Amfileri',
    icon: Icons.speaker_group_outlined,
    assetPath: 'assets/backline_icons/bassamps.png',
    children: [
      'Bas Combo Amfileri',
      'Bas Amfi Kafaları',
      'Bas Kabinleri',
      'Bas Preamp, DI & Efektler',
    ],
  ),
  _BacklineCategory(
    name: 'Piyano, Klavye & Synth',
    icon: Icons.keyboard_outlined,
    assetPath: 'assets/backline_icons/pianokeyboardsynth.png',
    children: [
      'Akustik Piyanolar',
      'Dijital & Sahne Piyanoları',
      'Keyboard & Workstationlar',
      'Synthesizerlar',
      'Orglar',
      'Elektromekanik Piyanolar (Rhodes vb.)',
      'MIDI Klavyeler & Controllerlar',
      'Klavye Amfileri',
      'Klavye Standları, Pedallar & Tabureler',
    ],
  ),
  _BacklineCategory(
    name: 'Perküsyon',
    icon: Icons.blur_circular_outlined,
    assetPath: 'assets/backline_icons/percussion.png',
    children: [
      'Conga, Tumba & Quinto',
      'Bongo',
      'Timbales',
      'Djembe',
      'Cajon',
      'Darbuka, Bendir, Tef & Asma Davul',
      'Udu, Shekere & Dünya Perküsyonları',
      'Shaker, Marakas, Cabasa & Küçük Perküsyonlar',
      'Jam Block, Cowbell, Chimes & Efekt Perküsyonları',
      'Perküsyon Masaları, Standları & Aksesuarları',
    ],
  ),
  _BacklineCategory(
    name: 'Gitarlar & Baslar',
    icon: Icons.music_note_outlined,
    assetPath: 'assets/backline_icons/guitarsandbasses.png',
    children: [
      'Elektro Gitarlar',
      'Akustik & Klasik Gitarlar',
      'Elektro Bas Gitarlar',
      'Akustik Bas Gitarlar',
      'Kontrbaslar',
      'Gitar & Bas Aksesuarları',
    ],
  ),
  _BacklineCategory(
    name: 'Yaylılar & Orkestra Enstrümanları',
    icon: Icons.queue_music_outlined,
    assetPath: 'assets/backline_icons/stringinstruments.png',
    children: [
      'Yaylı Enstrümanlar',
      'Nefesli Enstrümanlar',
      'Bakır Üflemeli Enstrümanlar',
      'Halk & Dünya Enstrümanları',
      'Orkestra Aksesuarları',
    ],
  ),
  _BacklineCategory(
    name: 'DJ Ekipmanları',
    icon: Icons.graphic_eq_outlined,
    assetPath: 'assets/backline_icons/dj-turntable.png',
    children: [
      'CDJ & Medya Oynatıcılar',
      'Turntablelar',
      'DJ Mikserleri',
      'DJ Controllerlar',
      'Sampler & Drum Machine',
      'DJ Monitörleri & Aksesuarları',
    ],
  ),
  _BacklineCategory(
    name: 'Pro Audio & Stüdyo',
    icon: Icons.mic_none_outlined,
    children: [
      'Dinamik Mikrofonlar',
      'Kondansatör & Ribbon Mikrofonlar',
      'Kablosuz Mikrofon Sistemleri',
      'Analog & Dijital Mikserler',
      'PA Hoparlörleri & Subwooferlar',
      'Sahne Monitörleri',
      'In-Ear Monitor Sistemleri',
      'DI Box & Reamp Kutuları',
      'Ses Kartları & Kayıt Cihazları',
      'Stüdyo Monitörleri',
      'Outboard, Preamp & Sinyal İşlemciler',
    ],
  ),
  _BacklineCategory(
    name: 'Sahne & Backline Aksesuarları',
    icon: Icons.handyman_outlined,
    children: [
      'Enstrüman, Mikrofon & Hoparlör Standları',
      'Nota Sehpaları',
      'Davul Tabureleri & Piyano Bankları',
      'Kablolar, Multicorelar & Adaptörler',
      'Güç Dağıtımı, Regülatörler & Trafolar',
      'Rack, Case & Taşıma Çözümleri',
      'Riser & Sahne Platformları',
      'Sarf Malzemeleri & Yedek Parçalar',
    ],
  ),
];

class _BacklineCategory {
  final String name;
  final IconData icon;
  final String? assetPath;
  final List<String> children;

  const _BacklineCategory({
    required this.name,
    required this.icon,
    this.assetPath,
    required this.children,
  });
}

class _BacklineCategoriesScreen extends StatelessWidget {
  const _BacklineCategoriesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tüm Backline Kategorileri',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: _backlineCategories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _BacklineCategoryTile(category: _backlineCategories[index]),
      ),
    );
  }
}

class _BacklineCategoryTile extends StatelessWidget {
  final _BacklineCategory category;

  const _BacklineCategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        iconColor: const Color(0xFFFF8A8A),
        collapsedIconColor: const Color(0xFF9AA4B2),
        leading: _BacklineCategoryIcon(category: category),
        title: Text(
          category.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        children: [
          const Divider(height: 1, color: Color(0xFF202B3A)),
          for (final subcategory in category.children)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 54, right: 12),
              title: Text(
                subcategory,
                style: const TextStyle(
                  color: Color(0xFFB5BDCA),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF758092),
                size: 18,
              ),
              onTap: () => Navigator.of(context).pop(subcategory),
            ),
        ],
      ),
    );
  }
}

class _BacklineCategoryIcon extends StatelessWidget {
  final _BacklineCategory category;

  const _BacklineCategoryIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    final assetPath = category.assetPath;
    if (assetPath == null) {
      return _StudioSocialGradientIcon(category.icon, size: 20);
    }

    final image = Image.asset(
      assetPath,
      width: 26,
      height: 26,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) =>
          Icon(category.icon, size: 22, color: Colors.white),
    );
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          LinearGradient(colors: AppColors.brandGradient).createShader(bounds),
      child: image,
    );
  }
}
