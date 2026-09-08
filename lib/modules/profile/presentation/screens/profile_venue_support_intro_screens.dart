part of 'profile_venue_support.dart';

class VenueIntroScreen extends StatefulWidget {
  VenueIntroScreen({super.key});

  @override
  State<VenueIntroScreen> createState() => _VenueIntroScreenState();
}

class _VenueIntroScreenState extends State<VenueIntroScreen> {
  bool _dontShowAgain = false;
  bool _savingPreference = false;

  Future<void> _continue() async {
    if (_savingPreference) return;
    setState(() => _savingPreference = true);
    try {
      if (_dontShowAgain) {
        await setVenueConnectionIntroHidden(true);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _savingPreference = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navBlueDeep,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mekan Bağlantı Süreci',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 30,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Devam etmeden önce kısa bir bilgi',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 28),
                      _VenueIntroStep(
                        icon: Icons.send_outlined,
                        title: 'İstek Gönder',
                        text:
                            'Sahne aldığın mekanlara kendin veya grubun adına bağlantı isteği gönderebilirsin. Mekana bildirim gider. Bağlantı ancak karşı taraf kabul ettiğinde kurulur.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.hourglass_top_rounded,
                        title: 'İki Profilde de Görün',
                        text:
                            'Onaydan sonra mekan, isteği gönderdiğin müzisyen veya grup profilinin Çaldığı Mekanlar alanında görünür. İlgili sanatçı profili de mekanın Aktif Sanatçılar alanında yer alır. Bu kartlardan birbirinizin profiline ulaşılabilir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.event_outlined,
                        title: 'Etkinliklerde Gösterim Sana Bağlı',
                        text:
                            'Bağlı olduğun mekan seni veya grubunu bir etkinliğe eklediğinde ilgili profilin bağlantısı etkinlikte açılır. Etkinlik kendi profilinde otomatik görünmez. Bunun için gelen gösterim davetini kabul etmen gerekir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.settings_outlined,
                        title: 'Durumu Takip Et',
                        text:
                            'Yönetim Paneli → Mekan Bağlantıları bölümünde Gelen İstekler ve Gönderdiğim İstekler listelerini takip edebilirsin. Aktif bağlantılarını Bağlantılarım alanından görebilir ve kaldırabilirsin.',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _savingPreference
                    ? null
                    : () => setState(() => _dontShowAgain = !_dontShowAgain),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _dontShowAgain,
                        onChanged: _savingPreference
                            ? null
                            : (value) => setState(
                                () => _dontShowAgain = value ?? false,
                              ),
                        activeColor: AppColors.coralAlt,
                      ),
                      Expanded(
                        child: Text(
                          'Bunu bir daha gösterme',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: GradientOutlineButton(
                  onPressed: _savingPreference ? null : _continue,
                  strokeWidth: 1,
                  loading: _savingPreference,
                  label: _savingPreference
                      ? 'Kaydediliyor...'
                      : 'Anladım, devam et',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MusicianIntroScreen extends StatelessWidget {
  MusicianIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navBlueDeep,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sanatçı Bağlantı Süreci',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 30,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Devam etmeden önce kısa bir bilgi',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 28),
                      _VenueIntroStep(
                        icon: Icons.send_outlined,
                        title: 'İstek Gönder',
                        text:
                            'Mekanında sahne alan müzisyenlere veya gruplara bağlantı isteği gönderebilirsin. Müzisyene veya grup kurucusuna bildirim gider. Bağlantı ancak karşı taraf kabul ettiğinde kurulur.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.hourglass_top_rounded,
                        title: 'İki Profilde de Görün',
                        text:
                            'Onaydan sonra müzisyen veya grup, mekanının Aktif Sanatçılar alanında görünür. Mekanın da ilgili sanatçı profilinin Çaldığı Mekanlar alanında yer alır. Bu kartlardan birbirinizin profiline ulaşılabilir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.event_outlined,
                        title: 'Etkinlik Gösterimi Ayrı Bir Tercih',
                        text:
                            'Bağlı olduğun müzisyeni veya grubu etkinliğine eklediğinde sanatçının profil bağlantısı etkinlikte açılır. Etkinlik sanatçının profilinde otomatik görünmez. Bunun için sanatçıya gönderilen gösterim davetinin kabul edilmesi gerekir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.settings_outlined,
                        title: 'Durumu Takip Et',
                        text:
                            'Yönetim Paneli → Sanatçı Bağlantıları bölümünde Gelen İstekler ve Gönderdiğim İstekler listelerini takip edebilirsin. Aktif bağlantılarını Bağlantılarım alanından görebilir ve kaldırabilirsin.',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: GradientOutlineButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  strokeWidth: 1,
                  label: 'Anladım, devam et',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VenueIntroStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  _VenueIntroStep({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2, right: 10),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.socialOrange,
                AppColors.socialPink,
                AppColors.socialPurple,
              ],
            ).createShader(bounds),
            child: Icon(icon, size: 20, color: AppColors.white),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.44,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
