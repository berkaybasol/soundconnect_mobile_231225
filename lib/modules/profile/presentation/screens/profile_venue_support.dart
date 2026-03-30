import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';

class VenueOption {
  final String id;
  final String name;
  final String? cityId;
  final String? districtId;
  final String? neighborhoodId;
  final String? cityName;
  final String? districtName;
  final String? neighborhoodName;

  const VenueOption({
    required this.id,
    required this.name,
    this.cityId,
    this.districtId,
    this.neighborhoodId,
    this.cityName,
    this.districtName,
    this.neighborhoodName,
  });
}

class VenueLookupOption {
  final String id;
  final String name;

  const VenueLookupOption({required this.id, required this.name});
}

class VenueConnection {
  final String requestId;
  final String venueId;
  final String venueName;

  const VenueConnection({
    required this.requestId,
    required this.venueId,
    required this.venueName,
  });
}

class VenueRequestPayload {
  final String venueId;
  final String message;

  const VenueRequestPayload({required this.venueId, required this.message});
}

class VenueIntroScreen extends StatelessWidget {
  const VenueIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navBlueDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mekan Bağlantı Süreci',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Devam etmeden önce kısa bilgi',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _VenueIntroStep(
                        icon: Icons.send_outlined,
                        title: 'İstek Gönder',
                        text:
                            'Aktif olarak sahne aldığın mekanlara buradan bağlantı isteği gönderebilirsin. İstek gönderdiğinde ilgili mekana bir bildirim iletilir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.hourglass_top_rounded,
                        title: 'Onay Bekle',
                        text:
                            'Mekan bağlantı isteğini onaylayabilir veya reddedebilir. Onaylandığında bağlantınız kurulacak ve hem senin profilinde hem de mekanın profilinde görünür hale gelecektir.',
                      ),
                      SizedBox(height: 22),
                      _VenueIntroStep(
                        icon: Icons.settings_outlined,
                        title: 'Durumu Takip Et',
                        text:
                            'Gönderdiğin bağlantı isteklerinin durumunu istediğin zaman Ayarlar → Başvurularım bölümünden görüntüleyebilir ve sürecin hangi aşamada olduğunu takip edebilirsin.',
                        showInlineSettingsIcon: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coralAlt,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Anladım, Devam Et'),
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

  const _VenueIntroStep({
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
          padding: const EdgeInsets.only(top: 2, right: 10),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7A3D), Color(0xFFEF5F86), Color(0xFFB85CFF)],
            ).createShader(bounds),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              if (showInlineSettingsIcon && text.contains('Ayarlar'))
                Builder(
                  builder: (_) {
                    const bodyStyle = TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.44,
                    );
                    final idx = text.indexOf('Ayarlar');
                    final left = text.substring(0, idx);
                    const focus = 'Ayarlar → Başvurularım';
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
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.settings,
                                size: 15,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          TextSpan(text: beforeFocus),
                          if (focusedText.isNotEmpty)
                            const TextSpan(
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
                  style: const TextStyle(
                    color: AppColors.textMuted,
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

class ProfileBottomBar extends StatelessWidget {
  final String? profileImageUrl;

  const ProfileBottomBar({super.key, this.profileImageUrl});

  Widget _profileAvatar(bool active) {
    final hasImage = profileImageUrl?.trim().isNotEmpty == true;
    final imageUrl = profileImageUrl?.trim() ?? '';
    final child = hasImage
        ? ClipOval(
            child: Image.network(
              imageUrl,
              width: 18,
              height: 18,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person_outline, size: 18),
            ),
          )
        : const Icon(Icons.person_outline, size: 18);

    if (!active) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: child),
      );
    }

    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(1.4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navBlueDeep,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.navBlueDeep, width: 1),
        ),
        child: Center(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 3,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.navBlueDeep,
      selectedItemColor: AppColors.coralAlt,
      unselectedItemColor: AppColors.textMuted,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.campaign_outlined),
          label: 'İlan',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.rocket_launch_outlined),
          label: 'Git',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.forum_outlined),
          label: 'Mesajlar',
        ),
        BottomNavigationBarItem(
          icon: _profileAvatar(false),
          activeIcon: _profileAvatar(true),
          label: 'Profil',
        ),
      ],
    );
  }
}
