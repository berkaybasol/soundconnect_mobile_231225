import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/musician_feed_models.dart';
import 'musician_feed_card_chrome.dart';
import 'musician_feed_card_registry.dart';

Widget buildCompletionFeedCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) {
  final payload = item.payload as CompletionFeedPayload;
  return MusicianFeedSurface(
    item: item,
    actions: actions,
    showAuthor: false,
    child: _CompletionCarousel(payload: payload, actions: actions),
  );
}

Widget buildSponsoredFeedCard(
  BuildContext context,
  MusicianFeedItem item,
  MusicianFeedCardActions actions,
) {
  final payload = item.payload as SponsoredFeedPayload;
  return MusicianFeedSurface(
    item: item,
    actions: actions,
    showAuthor: item.author != null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          payload.title,
          style: const TextStyle(
            fontSize: 18,
            height: 1.22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          payload.body,
          style: const TextStyle(fontSize: 13.5, height: 1.42),
        ),
        if (payload.mediaUrl != null) ...[
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: AppCachedNetworkImage(
                imageUrl: payload.mediaUrl,
                cacheWidth: 1080,
                placeholderBuilder: (_) => const _PromotionFallback(),
                errorBuilder: (_) => const _PromotionFallback(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          child: GradientOutlineButton(
            label: payload.ctaLabel,
            onPressed: () => actions.openPromotion(item),
            backgroundColor: AppColors.navBlue,
            leading: const Icon(Icons.arrow_forward_rounded, size: 18),
          ),
        ),
      ],
    ),
  );
}

class _CompletionCarousel extends StatefulWidget {
  const _CompletionCarousel({required this.payload, required this.actions});
  final CompletionFeedPayload payload;
  final MusicianFeedCardActions actions;

  @override
  State<_CompletionCarousel> createState() => _CompletionCarouselState();
}

class _CompletionCarouselState extends State<_CompletionCarousel> {
  late final PageController _controller;
  int _page = 0;

  List<MusicianFeedCompletionTask> get _tasks =>
      widget.payload.tasks
          .where((task) => !task.complete)
          .toList(growable: false)
        ..sort((left, right) => left.priority.compareTo(right.priority));

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .94);
  }

  @override
  void didUpdateWidget(covariant _CompletionCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastPage = (_tasks.length - 1).clamp(0, 0x7fffffff);
    if (_page <= lastPage) return;
    _page = lastPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.jumpToPage(_page);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final taskCardHeight = 194.0 + ((textScale - 1).clamp(0.0, 2.0) * 100.0);
    final total = widget.payload.total;
    final fraction = total <= 0
        ? 0.0
        : (widget.payload.completed / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Akışını sana göre hazırlayalım',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${widget.payload.completed}/$total',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: AppColors.navBlueSoft,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.coral),
          ),
        ),
        const SizedBox(height: 14),
        if (tasks.isEmpty)
          const _CompletionDone()
        else ...[
          SizedBox(
            height: taskCardHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: tasks.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: index == tasks.length - 1 ? 0 : 9,
                  ),
                  child: _CompletionTaskCard(
                    task: task,
                    onTap: () => widget.actions.openCompletionTask(task),
                  ),
                );
              },
            ),
          ),
          if (tasks.length > 1) ...[
            const SizedBox(height: 11),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                tasks.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _page ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _page ? AppColors.coral : AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _CompletionTaskCard extends StatelessWidget {
  const _CompletionTaskCard({required this.task, required this.onTap});
  final MusicianFeedCompletionTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
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
                  color: AppColors.navBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: BrandGradientIcon.social(
                    _taskIcon(task.code),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              task.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: GradientOutlineButton(
              label: task.ctaLabel,
              onPressed: onTap,
              backgroundColor: AppColors.navBlue,
              horizontalPadding: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionDone extends StatelessWidget {
  const _CompletionDone();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: const Row(
      children: [
        BrandGradientIcon.social(Icons.check_circle_outline_rounded, size: 25),
        SizedBox(width: 11),
        Expanded(
          child: Text(
            'Temel bilgiler tamam. Akışın seni tanıdıkça daha da güçlenecek.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _PromotionFallback extends StatelessWidget {
  const _PromotionFallback();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.uploadCardGradient,
      ),
    ),
    child: const Center(
      child: BrandGradientIcon.social(Icons.campaign_outlined, size: 42),
    ),
  );
}

IconData _taskIcon(String code) => switch (code.toUpperCase()) {
  'OPPORTUNITY_CITY' || 'CITY' => Icons.location_on_outlined,
  'INSTRUMENTS' || 'INSTRUMENT' => Icons.music_note_rounded,
  'STAGE_NAME_AND_BIO' ||
  'STAGE_NAME' ||
  'BIO' ||
  'PROFILE_DETAILS' => Icons.badge_outlined,
  'PORTFOLIO' || 'MEDIA' => Icons.library_music_outlined,
  'PROFILE_PHOTO_AND_SOCIAL_LINKS' => Icons.account_circle_outlined,
  'PROFILE_PHOTO' || 'PHOTO' => Icons.add_a_photo_outlined,
  'SOCIAL_LINKS' || 'SOCIAL' => Icons.link_rounded,
  _ => Icons.auto_awesome_rounded,
};
