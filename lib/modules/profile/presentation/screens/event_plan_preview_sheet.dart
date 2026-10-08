import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/entities/event_plan.dart';
import '../../domain/event_plan_repository.dart';
import 'event_plan_date_label.dart';

/// Server-confirmed preview. Closing this route never writes a plan.
class EventPlanPreviewSheet extends StatefulWidget {
  const EventPlanPreviewSheet({
    super.key,
    required this.definition,
    required this.repository,
    this.sessions,
    this.planId,
    this.expectedVersion,
  });
  final EventPlanDefinition definition;
  final EventPlanRepository repository;
  final AuthSessionManager? sessions;
  final String? planId;
  final int? expectedVersion;
  @override
  State<EventPlanPreviewSheet> createState() => _PreviewState();
}

class _PreviewState extends State<EventPlanPreviewSheet> {
  EventPlanPreview? _preview;
  String? _error;
  bool _loading = false;
  final Set<String> _excluded = {};
  late final AuthSessionManager? _sessions;
  Object? _session;
  bool get _current =>
      _sessions == null || identical(_session, _sessions.session);
  @override
  void initState() {
    super.initState();
    _sessions =
        widget.sessions ??
        (serviceLocator.isRegistered<AuthSessionManager>()
            ? serviceLocator<AuthSessionManager>()
            : null);
    _session = _sessions?.session;
    _sessions?.addListener(_changed);
    _excluded.addAll(widget.definition.excludedDates.map(eventPlanDate));
    _load();
  }

  void _changed() {
    if (mounted && !_current) {
      setState(() {
        _preview = null;
        _loading = false;
        _error = 'Oturum değişti. Formu yeniden aç.';
      });
    }
  }

  Future<void> _load({bool confirm = false}) async {
    if (_loading || !_current) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final definition = widget.definition.withExclusions(
      _excluded.map(DateTime.parse),
    );
    try {
      // Keep excluded rows selectable in the first preview. Final preview is
      // authoritative for the exact exclusions submitted by the user.
      final result = await widget.repository.preview(
        confirm ? definition : definition.withExclusions([]),
        planId: widget.planId,
        expectedVersion: widget.expectedVersion,
      );
      if (!mounted || !_current) return;
      if (result.isSuccess && result.data != null) {
        if (confirm) {
          Navigator.of(context).pop(definition);
          return;
        }
        setState(() {
          _preview = result.data;
          _loading = false;
        });
      } else {
        setState(() {
          _error = result.error?.message ?? 'Tarihler alınamadı.';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && _current) {
        setState(() {
          _loading = false;
          _error = 'Tarihler alınamadı. Yeniden dene.';
        });
      }
    }
  }

  @override
  void dispose() {
    _sessions?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: appSurfaceTheme(Theme.of(context)),
    child: Builder(builder: _buildSheet),
  );

  Widget _buildSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedCount = _preview?.dates
        .where((date) => !_excluded.contains(eventPlanDate(date)))
        .length;
    final muted = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 12,
      height: 1.5,
    );

    return Material(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tarihleri kontrol et',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Programına eklemek istemediğin tarihleri çıkarabilirsin.',
                      style: muted.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: scheme.error)),
                      TextButton(
                        onPressed: _loading || !_current ? null : _load,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                    if (_loading)
                      LinearProgressIndicator(
                        color: AppColors.brandGradient.last,
                        backgroundColor: scheme.outlineVariant,
                      ),
                    if (_preview != null) ...[
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            'YAKLAŞAN TARİHLER',
                            style: muted.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '$selectedCount tarih seçili',
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_preview!.dates.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            widget.planId == null
                                ? 'Bu aralıkta hazırlanacak tarih yok. Başlangıç yaklaştığında etkinlikler hazırlanır.'
                                : 'Bu aralıkta toplu düzenlemeye dahil tarih yok.',
                            style: muted,
                          ),
                        ),
                      for (final date in _preview!.dates)
                        _buildDateRow(context, date),
                      const SizedBox(height: 4),
                      Text(
                        _preview!.hasMore
                            ? '${eventPlanDateLabel(_preview!.throughDate, includeWeekday: false)} tarihine kadar olan etkinlikler hazırlanır. Program devam ettikçe yeni tarihler eklenir.'
                            : 'Seçtiğin tarihler, etkinlik günü yaklaştığında hazırlanır.',
                        style: muted.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      if (_preview!.preservedDates.isNotEmpty) ...[
                        Text(
                          'Korunan tarihler',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bu tarihler seçili tarih sayısına dahil değildir ve programı düzenlerken korunur.',
                          style: muted,
                        ),
                        const SizedBox(height: 10),
                        for (final date in _preview!.preservedDates)
                          _buildPreservedDateRow(context, date),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPreservedDateRow(
    BuildContext context,
    EventPlanPreservedDate date,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final description = switch (date.status) {
      'OVERRIDDEN' => 'Ayrı düzenlendi; bu değişiklikten etkilenmez',
      'SKIPPED' => 'Atlandı; yeniden eklenmez',
      'CANCELLED' => 'İptal edildi; yeniden eklenmez',
      _ => 'Başladı; bu değişiklikten etkilenmez',
    };
    return Container(
      key: ValueKey('plan-preserved-${eventPlanDate(date.scheduledDate)}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventPlanDateLabel(date.eventDate),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                if (date.eventDate != date.scheduledDate) ...[
                  const SizedBox(height: 4),
                  Text(
                    'İlk planlanan: ${eventPlanDateLabel(date.scheduledDate)}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.lock_outline_rounded,
            color: scheme.onSurfaceVariant,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(BuildContext context, DateTime date) {
    final scheme = Theme.of(context).colorScheme;
    final included = !_excluded.contains(eventPlanDate(date));
    final template = widget.definition.template;
    final time = template.startTime.substring(0, 5);
    final endTime = template.endTime?.substring(0, 5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: included ? scheme.surfaceContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: included ? scheme.outline : scheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CheckboxListTile(
          key: ValueKey('plan-preview-${eventPlanDate(date)}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 3,
          ),
          dense: true,
          activeColor: AppColors.brandGradient.last,
          checkColor: AppColors.onAccent,
          checkboxShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          side: BorderSide(color: scheme.onSurfaceVariant, width: 1.3),
          title: Text(
            eventPlanDateLabel(date),
            style: TextStyle(
              color: included ? scheme.onSurface : scheme.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              included
                  ? '$time${endTime == null ? '' : ' – $endTime'}'
                  : 'Plana dahil değil',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          value: included,
          onChanged: _loading || !_current
              ? null
              : (value) => setState(() {
                  if (value == true) {
                    _excluded.remove(eventPlanDate(date));
                  } else {
                    _excluded.add(eventPlanDate(date));
                  }
                }),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientOutline(
            radius: 10,
            strokeWidth: .9,
            colors: _loading || _preview == null || !_current
                ? [
                    Theme.of(context).dividerColor,
                    Theme.of(context).dividerColor,
                  ]
                : AppColors.brandGradient,
            child: OutlinedButton.icon(
              key: const Key('plan-preview-confirm'),
              onPressed: _loading || _preview == null || !_current
                  ? null
                  : () => _load(confirm: true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: Icon(
                Icons.check_rounded,
                color: AppColors.brandGradient[2],
                size: 19,
              ),
              label: const Text('Planı kaydet'),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Forma dön'),
          ),
        ],
      ),
    ),
  );
}
