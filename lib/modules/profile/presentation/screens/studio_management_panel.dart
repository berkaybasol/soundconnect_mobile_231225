part of 'studio_profile_screen.dart';

class StudioManagementPanelScreen extends StatelessWidget {
  final StudioProfile profile;

  const StudioManagementPanelScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final profileName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'Studio';
    return Scaffold(
      appBar: AppBar(title: const Text('Yönetim Paneli'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      Theme.of(context).colorScheme.surfaceContainer,
                    ],
                  ),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GradientText(
                      text: profileName,
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppColors.brandGradient,
                      ),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Buradan stüdyo profilini destekleyen yönetim araçlarına erişebilirsin.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _StudioManagementActionCard(
                icon: Icons.meeting_room_outlined,
                title: 'Odalar',
                message: 'Mevcut odaları yönet ve yeni oda oluştur.',
                trailingLabel: 'Yönet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _StudioRoomsManagementScreen(
                      studioProfileId: profile.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.event_available_outlined,
                title: 'Rezervasyon Yönetimi',
                message: 'Tüm odaların rezervasyonlarını yönet.',
                trailingLabel: 'Yönet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _StudioReservationsHubScreen(
                      studioProfileId: profile.id,
                      timeZone: profile.timeZone,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.inventory_2_outlined,
                title: 'Envanter Yönetimi',
                message: 'Backline ekipmanlarını ekle, düzenle veya kaldır.',
                trailingLabel: 'Yönet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _StudioBacklineInventoryScreen(
                      studioProfileId: profile.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _StudioManagementActionCard(
                icon: Icons.event_available_outlined,
                title: 'Ekipman Takvimi',
                message: 'Ekipmanların dolu ve bakımda olduğu tarihleri yönet.',
                trailingLabel: 'Yönet',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const _BacklineAvailabilityManagementScreen(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
                ),
              ),
              _StudioManagementActionCard(
                icon: Icons.add_circle_outline_rounded,
                title: 'Kategori Talep Et',
                message: 'Yeni bir backline kategorisi veya alt kategori öner.',
                trailingLabel: 'Talep Et',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const _StudioBacklineCategoryManagementScreen(),
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

class _StudioManagementActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? trailingLabel;
  final VoidCallback? onTap;

  const _StudioManagementActionCard({
    required this.icon,
    required this.title,
    required this.message,
    this.trailingLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
      borderRadius: BorderRadius.circular(18),
      child: _StudioGradientOutline(
        radius: 18,
        strokeWidth: 1,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(context).colorScheme.surfaceContainer,
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              if (trailingLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    trailingLabel!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioGradientOutline extends StatelessWidget {
  final Widget child;
  final double radius;
  final double strokeWidth;

  const _StudioGradientOutline({
    required this.child,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StudioGradientOutlinePainter(
        radius: radius,
        strokeWidth: strokeWidth,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _StudioGradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;

  const _StudioGradientOutlinePainter({
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _StudioGradientOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
