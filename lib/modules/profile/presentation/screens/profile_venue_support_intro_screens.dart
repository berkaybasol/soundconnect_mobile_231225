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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _VenueIntroStep(
                        icon: Icons.send_outlined,
                        title: 'İstek Gönder',
                        text:
                            'Aktif olarak sahne aldığın mekanlara buradan bağlantı isteği gönderebilirsin. İstek gönderdiğinde ilgili mekana bildirim iletilir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.hourglass_top_rounded,
                        title: 'Onay Bekle',
                        text:
                            'Mekan bağlantı isteğini onaylayabilir veya reddedebilir. Onaylandığında bağlantınız kurulacak; hem senin profilinde hem de mekanın profilinde görünür hale gelir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.settings_outlined,
                        title: 'Durumu Takip Et',
                        text:
                            'Gönderdiğin bağlantı isteklerinin durumunu istediğin zaman Ayarlar -> Başvurularım bölümünden görüntüleyebilir ve sürecin hangi aşamada olduğunu takip edebilirsin.',
                        showInlineSettingsIcon: true,
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
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
                child: ElevatedButton(
                  onPressed: _savingPreference ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coralAlt,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(vertical: 17),
                    textStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _savingPreference ? 'Kaydediliyor...' : 'Anladım, devam et',
                  ),
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
              Text(
                'Müzisyen Bağlantı Süreci',
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _VenueIntroStep(
                        icon: Icons.send_outlined,
                        title: 'İstek Gönder',
                        text:
                            'Mekanında sahne alabilecek müzisyenlere buradan bağlantı isteği gönderebilirsin. İstek gönderdiğinde ilgili müzisyene bildirim iletilir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.hourglass_top_rounded,
                        title: 'Onay Bekle',
                        text:
                            'Müzisyen bağlantı isteğini onaylayabilir veya reddedebilir. Onaylandığında bağlantınız kurulacak; hem senin profilinde hem de müzisyenin profilinde görünür hale gelir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.settings_outlined,
                        title: 'Durumu Takip Et',
                        text:
                            'Gönderdiğin bağlantı isteklerinin durumunu istediğin zaman Ayarlar -> Başvurularım bölümünden görüntüleyebilir ve sürecin hangi aşamada olduğunu takip edebilirsin.',
                        showInlineSettingsIcon: true,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coralAlt,
                    foregroundColor: AppColors.white,
                    padding: EdgeInsets.symmetric(vertical: 17),
                    textStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('Anladım, devam et'),
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
  final bool showInlineSettingsIcon;

  _VenueIntroStep({
    required this.icon,
    required this.title,
    required this.text,
    this.showInlineSettingsIcon = false,
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
              if (showInlineSettingsIcon && text.contains('Ayarlar'))
                Builder(
                  builder: (_) {
                    final bodyStyle = TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    );
                    final idx = text.indexOf('Ayarlar');
                    final left = text.substring(0, idx);
                    const focus = 'Ayarlar -> Başvurularım';
                    final focusStart = text.indexOf(focus, idx);
                    final hasFocus = focusStart >= 0;
                    final beforeFocus = hasFocus
                        ? text.substring(idx, focusStart)
                        : text.substring(idx);
                    final focusedText = hasFocus ? focus : '';
                    final afterFocus = hasFocus
                        ? text.substring(focusStart + focus.length)
                        : '';
                    return RichText(
                      text: TextSpan(
                        style: bodyStyle,
                        children: [
                          TextSpan(text: left),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.settings,
                                size: 15,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextSpan(text: beforeFocus),
                          if (focusedText.isNotEmpty)
                            TextSpan(
                              text: focus,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          TextSpan(text: afterFocus),
                        ],
                      ),
                    );
                  },
                )
              else
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
