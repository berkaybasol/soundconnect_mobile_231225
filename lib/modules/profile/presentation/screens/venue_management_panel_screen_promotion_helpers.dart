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
    child: Transform.translate(offset: Offset(0, 4), child: child),
  );
}

Widget _buildManagementAdPlaceholderCard(BuildContext context) {
  return _GradientOutline(
    radius: 22,
    strokeWidth: 1,
    child: Ink(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainer,
          ],
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
                  gradient: LinearGradient(colors: AppColors.brandGradient),
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reklam Alani',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1240 / 400,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).dividerColor),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.navBlueDeep,
                    Theme.of(
                      context,
                    ).colorScheme.surfaceContainer.withValues(alpha: 0.94),
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
                    errorBuilder: (_, __, ___) => SizedBox.shrink(),
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

Widget _buildManagementPromotionFallback(BuildContext context) {
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
              Theme.of(
                context,
              ).colorScheme.surfaceContainer.withValues(alpha: 0.94),
            ],
          ),
        ),
        child: Center(
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
      final items = snapshot.data?.data ?? <PromotionItem>[];
      final item = items.isNotEmpty ? items.first : null;
      final imageUrl = item?.mediaUrl?.trim();
      final hasImage =
          imageUrl != null &&
          imageUrl.isNotEmpty &&
          (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

      if (item == null) return _buildManagementAdPlaceholderCard(context);

      return InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openManagementPromotionLink(item.redirectUrl),
        child: _GradientOutline(
          radius: 22,
          strokeWidth: 1,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  Theme.of(context).colorScheme.surfaceContainer,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1240 / 400,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      color: AppColors.navBlueDeep,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                      child: hasImage
                          ? _buildManagementShiftedBannerImage(
                              AppCachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                cacheProfile: AppImageCacheProfile.original,
                                errorBuilder: (context) =>
                                    _buildManagementPromotionFallback(context),
                              ),
                            )
                          : _buildManagementPromotionFallback(context),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navBlueDeep,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(
                          'Sponsorlu Icerik',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        item.title,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (item.description?.trim().isNotEmpty ?? false) ...[
                        SizedBox(height: 8),
                        Text(
                          item.description!.trim(),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
