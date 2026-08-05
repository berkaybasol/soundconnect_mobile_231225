part of 'studio_profile_screen.dart';

class _BacklineItemDetailScreen extends StatelessWidget {
  final _BacklineItem item;
  final bool ownerMode;
  final String? phone;
  final VoidCallback? onMessage;

  _BacklineItemDetailScreen({
    required this.item,
    required this.ownerMode,
    required this.phone,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BacklineDetailChrome(
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 8),
              _BacklineDetailHero(item: item),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.type,
                          style: const TextStyle(
                            color: Color(0xFFB7C0CE),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _BacklineStatus(label: item.status, color: item.statusColor),
                ],
              ),
              const SizedBox(height: 18),
              _BacklineInventorySummary(item: item),
              const SizedBox(height: 12),
              _BacklineDetailInfoCard(item: item),
              const SizedBox(height: 18),
              if (!ownerMode) ...[
                _BacklineContactActions(
                  onCall: () => _callStudio(context),
                  onWhatsApp: () => _openWhatsApp(context),
                  onMessage: () => _messageStudio(context),
                ),
                const SizedBox(height: 18),
              ],
              _BacklineAvailabilityCalendar(item: item, editable: ownerMode),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callStudio(BuildContext context) async {
    final uri = profilePhoneUri(phone);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stüdyonun geçerli telefon bilgisi bulunmuyor.'),
        ),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon uygulaması açılamadı.')),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = profileWhatsAppUri(phone);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stüdyonun geçerli WhatsApp numarası bulunmuyor.'),
        ),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('WhatsApp açılamadı.')));
    }
  }

  void _messageStudio(BuildContext context) {
    final callback = onMessage;
    if (callback != null) {
      callback();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mesajlaşma şu anda kullanılamıyor.')),
    );
  }
}

class _BacklineContactActions extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onMessage;

  const _BacklineContactActions({
    required this.onCall,
    required this.onWhatsApp,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _BacklineDetailGradientButton(
                icon: Icons.phone_outlined,
                label: 'Stüdyoyu Ara',
                filled: false,
                onTap: onCall,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BacklineDetailGradientButton(
                icon: Icons.chat_outlined,
                label: 'WhatsApp',
                filled: false,
                onTap: onWhatsApp,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _BacklineDetailGradientButton(
          icon: Icons.message_outlined,
          label: 'Mesaj Gönder',
          filled: true,
          onTap: onMessage,
        ),
      ],
    );
  }
}

class _BacklineDetailChrome extends StatelessWidget {
  final VoidCallback onBack;

  const _BacklineDetailChrome({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        const Spacer(),
      ],
    );
  }
}

class _BacklineDetailHero extends StatefulWidget {
  final _BacklineItem item;

  const _BacklineDetailHero({required this.item});

  @override
  State<_BacklineDetailHero> createState() => _BacklineDetailHeroState();
}

class _BacklineDetailHeroState extends State<_BacklineDetailHero> {
  final _pageController = PageController();
  int _activePage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.item.photoUrls.isEmpty
        ? 1
        : widget.item.photoUrls.length;
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            itemCount: pageCount,
            onPageChanged: (index) => setState(() => _activePage = index),
            itemBuilder: (context, index) {
              return _BacklineDetailHeroImage(item: widget.item, index: index);
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            pageCount,
            (index) => _BacklineHeroDot(active: index == _activePage),
          ),
        ),
      ],
    );
  }
}

class _BacklineDetailHeroImage extends StatelessWidget {
  final _BacklineItem item;
  final int index;

  const _BacklineDetailHeroImage({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = index < item.photoUrls.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.05,
          colors: [
            AppColors.socialPurple.withValues(alpha: 0.18),
            const Color(0xFF111824),
            const Color(0xFF070B12),
          ],
        ),
        border: Border.all(color: const Color(0xFF202B3A)),
        boxShadow: [
          BoxShadow(
            color: AppColors.pureBlack.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Stack(
              fit: StackFit.expand,
              children: [
                AppCachedNetworkImage(
                  imageUrl: item.photoUrls[index],
                  fit: BoxFit.cover,
                  cacheProfile: AppImageCacheProfile.original,
                  cacheWidth: 1200,
                  errorBuilder: (_) =>
                      _BacklineDetailPhotoPlaceholder(item: item),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC070B12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${index + 1}/${item.photoUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _BacklineDetailPhotoPlaceholder(item: item),
    );
  }
}

class _BacklineDetailPhotoPlaceholder extends StatelessWidget {
  final _BacklineItem item;

  const _BacklineDetailPhotoPlaceholder({required this.item});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 176,
        height: 122,
        decoration: BoxDecoration(
          color: const Color(0xFF101722),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF313B4D)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StudioSocialGradientIcon(item.icon, size: 46),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BacklineHeroDot extends StatelessWidget {
  final bool active;

  const _BacklineHeroDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: active
            ? LinearGradient(
                colors: [
                  AppColors.socialOrange,
                  AppColors.socialPink,
                  AppColors.socialPurple,
                ],
              )
            : null,
        color: active ? null : const Color(0xFF626C7A),
      ),
    );
  }
}

class _BacklineInventorySummary extends StatelessWidget {
  final _BacklineItem item;

  const _BacklineInventorySummary({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Row(
        children: [
          _BacklineCountCell(
            label: 'Toplam Adet',
            value: item.total.toString(),
          ),
          _BacklineCountDivider(),
          _BacklineCountCell(
            label: 'M\u00FCsait',
            value: item.available.toString(),
            color: const Color(0xFF15C46B),
          ),
          _BacklineCountDivider(),
          _BacklineCountCell(
            label: 'Dolu',
            value: item.busy.toString(),
            color: const Color(0xFFFFA000),
          ),
          _BacklineCountDivider(),
          _BacklineCountCell(
            label: 'Bak\u0131mda',
            value: item.maintenance.toString(),
          ),
        ],
      ),
    );
  }
}

class _BacklineCountCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _BacklineCountCell({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFB5BDCA), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineCountDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: const Color(0xFF273244));
  }
}

class _BacklineDetailInfoCard extends StatelessWidget {
  final _BacklineItem item;

  const _BacklineDetailInfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF101722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF202B3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.model.isNotEmpty)
            _BacklineInfoRow(
              icon: Icons.label_outline_rounded,
              label: 'Marka / Model',
              value: item.model,
            ),
          _BacklineInfoRow(
            icon: Icons.account_tree_outlined,
            label: 'Alt Kategori',
            value: item.subcategory,
            last: item.description.isEmpty && item.features.isEmpty,
          ),
          if (item.description.isNotEmpty)
            _BacklineInfoRow(
              icon: Icons.notes_outlined,
              label: 'A\u00E7\u0131klama',
              value: item.description,
              last: item.features.isEmpty,
            ),
          if (item.features.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                'Teknik Özellikler',
                style: TextStyle(
                  color: Color(0xFFB5BDCA),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final feature in item.features)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(feature),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _BacklineAvailabilityCalendar extends StatefulWidget {
  final _BacklineItem item;
  final bool editable;

  const _BacklineAvailabilityCalendar({
    required this.item,
    required this.editable,
  });

  @override
  State<_BacklineAvailabilityCalendar> createState() =>
      _BacklineAvailabilityCalendarState();
}

class _BacklineAvailabilityCalendarState
    extends State<_BacklineAvailabilityCalendar> {
  @override
  Widget build(BuildContext context) {
    return _BacklineDateAvailabilityCalendar(
      repository: serviceLocator<StudioEquipmentRepository>(),
      equipmentId: widget.item.id,
      studioProfileId: widget.item.studioProfileId,
      referenceDate: widget.item.referenceDate,
      equipmentName: widget.item.title,
      total: widget.item.total,
      initiallyAvailable: widget.item.available,
      initiallyMaintenance: widget.item.maintenance,
      editable: widget.editable,
    );
  }
}

class _CalendarArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CalendarArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF0A101A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFF263244) : const Color(0xFF1A2230),
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.socialPink : const Color(0xFF596272),
          size: 20,
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        const _CalendarLegendItem(
          color: Color(0xFF1EAF4D),
          label: 'M\u00FCsait',
        ),
        const _CalendarRatioLegendItem(),
        const _CalendarLegendItem(color: Color(0xFFB8323B), label: 'Dolu'),
        const _CalendarLegendItem(
          color: Color(0xFF6B7280),
          label: 'Bak\u0131mda',
        ),
      ],
    );
  }
}

class _CalendarLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFCDD3DE), fontSize: 12),
        ),
      ],
    );
  }
}

class _CalendarRatioLegendItem extends StatelessWidget {
  const _CalendarRatioLegendItem();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              colors: [Color(0xFFD85B47), Color(0xFFF59E0B), Color(0xFF1EAF4D)],
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Kısmen Müsait',
          style: TextStyle(color: Color(0xFFCDD3DE), fontSize: 12),
        ),
      ],
    );
  }
}

class _BacklineInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  const _BacklineInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF273244))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFB5BDCA), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFCDD3DE), fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFE5E9F0),
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklineDetailGradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _BacklineDetailGradientButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Container(
        height: 54,
        padding: filled ? EdgeInsets.zero : const EdgeInsets.all(0.8),
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: [
              AppColors.socialOrange,
              AppColors.socialPink,
              AppColors.socialPurple,
            ],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: filled ? radius : BorderRadius.circular(7.2),
            color: filled
                ? null
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BacklineStatus extends StatelessWidget {
  final String label;
  final Color color;

  const _BacklineStatus({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.computeLuminance() > 0.4 ? color : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final String label;
  final String value;
  final Color? dotColor;

  const _MiniMeta({required this.label, required this.value, this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0xFF8D97A6), fontSize: 10),
          ),
        if (dotColor != null) ...[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE1E6EF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TinyButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TinyButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A101A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF273244)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
