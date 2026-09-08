part of 'guest_event_home_screen.dart';

class _DiscoverySurface extends StatelessWidget {
  const _DiscoverySurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.navBlue,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
    ),
    child: child,
  );
}

class _DiscoveryLabel extends StatelessWidget {
  const _DiscoveryLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.3,
    ),
  );
}

class _DiscoveryChoice extends StatelessWidget {
  const _DiscoveryChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(0.8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: selected
              ? LinearGradient(colors: AppColors.brandGradient)
              : null,
          color: selected ? null : AppColors.border,
        ),
        child: Material(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12.2),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      BrandGradientIcon.social(icon!, size: 13),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DiscoveryField extends StatelessWidget {
  const _DiscoveryField({
    required this.label,
    required this.icon,
    this.onTap,
    this.loading = false,
    this.compact = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null && !loading,
    child: Material(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              if (!compact) ...[
                if (onTap != null && !loading)
                  BrandGradientIcon.social(icon, size: 20)
                else
                  Icon(icon, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onTap != null && !loading
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (loading)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (onTap != null)
                BrandGradientIcon.social(
                  Icons.keyboard_arrow_down_rounded,
                  size: compact ? 16 : 20,
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted,
                  size: compact ? 16 : 20,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DiscoveryPrimaryButton extends StatelessWidget {
  const _DiscoveryPrimaryButton({
    required this.label,
    this.onTap,
    this.loading = false,
    this.icon = Icons.search_rounded,
    this.brandBorder = true,
  });
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData? icon;
  final bool brandBorder;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null && !loading,
    label: loading ? 'Yükleniyor' : label,
    child: Container(
      padding: const EdgeInsets.all(0.9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: brandBorder && (onTap != null || loading)
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: !brandBorder || (onTap == null && !loading)
            ? AppColors.border
            : null,
      ),
      child: Material(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14.1),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (icon != null && onTap != null)
                    BrandGradientIcon.social(icon!, size: 19)
                  else if (icon != null)
                    Icon(icon!, size: 19, color: AppColors.textMuted),
                  if (loading || icon != null) const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: onTap == null && !loading
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DiscoveryAuthFooter extends StatelessWidget {
  const _DiscoveryAuthFooter();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    decoration: BoxDecoration(
      color: AppColors.navBlueDeep,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _DiscoveryPrimaryButton(
            label: 'Giriş Yap',
            icon: null,
            brandBorder: false,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.login),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DiscoveryPrimaryButton(
            label: 'Üye Ol',
            icon: null,
            onTap: () => openRegistrationOptions(context),
          ),
        ),
      ],
    ),
  );
}

class _DiscoveryBetaNotice extends StatelessWidget {
  const _DiscoveryBetaNotice({required this.onSuggest});

  final VoidCallback? onSuggest;

  @override
  Widget build(BuildContext context) => _DiscoverySurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Beta sürecinde olduğumuz için etkinlikler ağırlıklı olarak Ankara’da. '
          'Diğer şehirler için çalışmaya devam ediyoruz. 🌱',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'SoundConnect’te bulamadığın bir mekanı önererek mekanla '
          'iletişime geçmemize yardımcı olabilirsin.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        _DiscoveryPrimaryButton(
          label: 'Mekan öner',
          icon: Icons.add_location_alt_outlined,
          onTap: onSuggest,
        ),
      ],
    ),
  );
}

class _DiscoveryRetry extends StatelessWidget {
  const _DiscoveryRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(
            color: AppColors.textMuted,
            height: 1.45,
            fontSize: 13,
          ),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const BrandGradientIcon.social(Icons.refresh_rounded, size: 17),
          label: const Text('Tekrar dene'),
        ),
      ],
    ),
  );
}

class _DiscoveryDateSheet extends StatelessWidget {
  const _DiscoveryDateSheet({required this.today, required this.selected});
  final DateTime today;
  final DateTime selected;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Hangi gün?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Önümüzdeki günler',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          for (
            var offset = 2;
            offset < EventDiscoveryDatePolicy.dayCount;
            offset++
          ) ...[
            Builder(
              builder: (context) {
                final date = DateTime(
                  today.year,
                  today.month,
                  today.day + offset,
                );
                final active = date == selected;
                return Semantics(
                  selected: active,
                  button: true,
                  child: Container(
                    padding: const EdgeInsets.all(0.8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: active
                          ? LinearGradient(colors: AppColors.brandGradient)
                          : null,
                      color: active ? null : AppColors.border,
                    ),
                    child: Material(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(14.2),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(date),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${EventDiscoveryDatePolicy.longDate(date)} · ${EventDiscoveryDatePolicy.weekday(date)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: active
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              BrandGradientIcon.social(
                                active
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.chevron_right_rounded,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 9),
          ],
        ],
      ),
    ),
  );
}

class _DiscoveryLocationSheet extends StatefulWidget {
  const _DiscoveryLocationSheet({
    required this.title,
    required this.options,
    required this.allowAll,
    this.selectedId,
  });
  final String title;
  final List<_FilterOption> options;
  final String? selectedId;
  final bool allowAll;
  @override
  State<_DiscoveryLocationSheet> createState() =>
      _DiscoveryLocationSheetState();
}

class _DiscoveryLocationSheetState extends State<_DiscoveryLocationSheet> {
  String _query = '';
  String _fold(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final query = _fold(_query);
    final options = <_FilterOption>[
      if (widget.allowAll && query.isEmpty)
        const _FilterOption(value: '', label: 'Tümü'),
      ...widget.options.where((option) => _fold(option.label).contains(query)),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Ara',
                    prefixIcon: const BrandGradientIcon.social(
                      Icons.search_rounded,
                    ),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: options.isEmpty
                    ? Center(
                        child: Text(
                          'Sonuç bulunamadı.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: options.length,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final selected =
                              option.value == (widget.selectedId ?? '');
                          return ListTile(
                            title: Text(option.label),
                            selected: selected,
                            selectedColor: AppColors.coral,
                            trailing: selected
                                ? const BrandGradientIcon.social(
                                    Icons.check_rounded,
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(option),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryEventTile extends StatelessWidget {
  const _DiscoveryEventTile({required this.item});
  final DiscoveryEvent item;
  @override
  Widget build(BuildContext context) {
    final oldCard = _EventCard(item: item);
    final fallback = EventPosterFallback(title: item.title);
    final poster = item.posterImageUrl?.trim() ?? '';
    final location = [
      item.venueDistrict,
      item.venueCity,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
    return Material(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => oldCard._openDetail(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (poster.startsWith('https://') ||
                        poster.startsWith('http://'))
                      Image.network(
                        poster,
                        fit: BoxFit.cover,
                        cacheWidth: 900,
                        errorBuilder: (_, _, _) => fallback,
                      )
                    else
                      fallback,
                    Positioned(
                      left: 14,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navBlueDeep.withValues(alpha: .92),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          oldCard._timeLabel(),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const BrandGradientIcon.social(
                                    Icons.music_note_rounded,
                                    size: 17,
                                    semanticLabel: 'Sanatçı veya grup',
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      item.performerName.trim().isEmpty
                                          ? 'Belirtilmemiş'
                                          : item.performerName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // This is a visual cue for the whole card's action,
                        // not a separate small tap target or venue profile link.
                        ExcludeSemantics(
                          child: Container(
                            key: ValueKey('discovery-event-open-${item.id}'),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.navBlue,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Center(
                              child: BrandGradientIcon.social(
                                Icons.chevron_right_rounded,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const BrandGradientIcon.social(
                          Icons.location_on_outlined,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            item.venueName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5, left: 24),
                        child: Text(
                          location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openDiscoveryTableGate(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.navBlueDeep,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masalar',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Masaları görmek veya masa açmak için giriş yap.',
                style: TextStyle(color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 22),
              _GradientActionButton(
                label: 'Giriş yap',
                backgroundColor: AppColors.navBlueDeep,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed(AppRoutes.login);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed(AppRoutes.register);
                },
                child: const Text('Üye ol'),
              ),
            ],
          ),
        ),
      ),
    );
