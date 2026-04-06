part of 'venue_management_panel_screen.dart';

Future<void> _openManagementPromotionLink(String? rawUrl) async {
  final url = rawUrl?.trim();
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Widget _buildManagementShiftedBannerImage(Widget child) {
  return ClipRect(
    child: Transform.translate(offset: const Offset(0, 4), child: child),
  );
}

Widget _buildManagementAdPlaceholderCard() {
  return _GradientOutline(
    radius: 22,
    strokeWidth: 1,
    child: Ink(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.inputFill, AppColors.navBlueSoft],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: AppColors.brandGradient,
                  ),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Reklam Alani',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1240 / 400,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.navBlueDeep,
                    AppColors.navBlueSoft.withValues(alpha: 0.94),
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _buildManagementShiftedBannerImage(
                  Image.asset(
                    'assets/buraya bakarlar v3.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildManagementPromotionFallback() {
  return _buildManagementShiftedBannerImage(
    Image.asset(
      'assets/buraya bakarlar v3.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.navBlueDeep,
              AppColors.navBlueSoft.withValues(alpha: 0.94),
            ],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.campaign_outlined,
            color: AppColors.white,
            size: 36,
          ),
        ),
      ),
    ),
  );
}

Widget _buildManagementPromotionCard(BuildContext context) {
  final repository = serviceLocator<PromotionRepository>();
  return FutureBuilder<Result<List<PromotionItem>>>(
    future: repository.getDisplayableByPlacement('VENUE_MANAGEMENT_PANEL'),
    builder: (context, snapshot) {
      final items = snapshot.data?.data ?? const <PromotionItem>[];
      final item = items.isNotEmpty ? items.first : null;
      final imageUrl = item?.mediaUrl?.trim();
      final hasImage =
          imageUrl != null &&
          imageUrl.isNotEmpty &&
          (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

      if (item == null) return _buildManagementAdPlaceholderCard();

      return InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openManagementPromotionLink(item.redirectUrl),
        child: _GradientOutline(
          radius: 22,
          strokeWidth: 1,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.inputFill, AppColors.navBlueSoft],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1240 / 400,
                  child: Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      color: AppColors.navBlueDeep,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      child: hasImage
                          ? _buildManagementShiftedBannerImage(
                              Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) =>
                                    _buildManagementPromotionFallback(),
                              ),
                            )
                          : _buildManagementPromotionFallback(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navBlueDeep,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'Sponsorlu Icerik',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (item.description?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        Text(
                          item.description!.trim(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
