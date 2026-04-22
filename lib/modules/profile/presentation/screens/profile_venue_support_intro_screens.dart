part of 'profile_venue_support.dart';

class VenueIntroScreen extends StatelessWidget {
  VenueIntroScreen({super.key});

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
                'Mekan Baglanti Sureci',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Devam etmeden once kisa bilgi',
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
                        title: 'Istek Gonder',
                        text:
                            'Aktif olarak sahne aldigin mekanlara buradan baglanti istegi gonderebilirsin. Istek gonderdiginde ilgili mekana bir bildirim iletilir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.hourglass_top_rounded,
                        title: 'Onay Bekle',
                        text:
                            'Mekan baglanti istegini onaylayabilir veya reddedebilir. Onaylandiginda baglantiniz kurulacak ve hem senin profilinde hem de mekanin profilinde gorunur hale gelecektir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.settings_outlined,
                        title: 'Durumu Takip Et',
                        text:
                            'Gonderdigin baglanti isteklerinin durumunu istedigin zaman Ayarlar -> Basvurularim bolumunden goruntuleyebilir ve surecin hangi asamada oldugunu takip edebilirsin.',
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
                  child: Text('Anladim, Devam Et'),
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
                'Muzisyen Baglanti Sureci',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Devam etmeden once kisa bilgi',
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
                        title: 'Istek Gonder',
                        text:
                            'Mekaninda sahne alabilecek muzisyenlere buradan baglanti istegi gonderebilirsin. Istek gonderdiginde ilgili muzisyene bir bildirim iletilir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.hourglass_top_rounded,
                        title: 'Onay Bekle',
                        text:
                            'Muzisyen baglanti istegini onaylayabilir veya reddedebilir. Onaylandiginda baglantiniz kurulacak ve hem senin profilinde hem de muzisyenin profilinde gorunur hale gelecektir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.settings_outlined,
                        title: 'Durumu Takip Et',
                        text:
                            'Gonderdigin baglanti isteklerinin durumunu istedigin zaman Ayarlar -> Basvurularim bolumunden goruntuleyebilir ve surecin hangi asamada oldugunu takip edebilirsin.',
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
                  child: Text('Anladim, Devam Et'),
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
                    const focus = 'Ayarlar -> Basvurularim';
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
