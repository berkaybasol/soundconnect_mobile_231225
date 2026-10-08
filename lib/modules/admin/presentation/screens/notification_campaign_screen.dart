import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/soundconnect_date_picker.dart';
import '../../../../shared/widgets/soundconnect_time_picker.dart';
import '../../../collab/presentation/widgets/collab_discovery_widgets.dart';
import '../../data/notification_campaign_repository.dart';
import '../../domain/notification_campaign.dart';
import '../widgets/admin_visual_theme.dart';

part 'notification_campaign_editor.dart';
part 'notification_campaign_lookup.dart';

/// Independent notification management. Opening this screen never sends a push.
class NotificationCampaignScreen extends StatelessWidget {
  const NotificationCampaignScreen({
    super.key,
    required this.repository,
    required this.sessions,
  });
  final NotificationCampaignRepository repository;
  final AuthSessionManager sessions;
  @override
  Widget build(BuildContext context) => AdminThemeScope(
    child: _CampaignScreenBody(repository: repository, sessions: sessions),
  );
}

class _CampaignScreenBody extends StatefulWidget {
  const _CampaignScreenBody({required this.repository, required this.sessions});
  final NotificationCampaignRepository repository;
  final AuthSessionManager sessions;
  @override
  State<_CampaignScreenBody> createState() =>
      _NotificationCampaignScreenState();
}

class _NotificationCampaignScreenState extends State<_CampaignScreenBody> {
  late final AuthSession _session;
  CampaignPage? _page;
  bool _busy = false, _revoked = false;
  String? _error;
  bool get _current =>
      mounted &&
      !_revoked &&
      identical(_session, widget.sessions.session) &&
      canManageNotificationCampaigns(widget.sessions.session);
  @override
  void initState() {
    super.initState();
    _session = widget.sessions.session;
    widget.sessions.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (!_current && mounted) {
      setState(() {
        _revoked = true;
        _page = null;
        _error = null;
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _load([int page = 0]) async {
    if (!_current || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.repository.load(page: page);
    if (!_current) return;
    setState(() {
      _busy = false;
      _page = result.data;
      _error = result.error?.message;
    });
  }

  Future<void> _open([NotificationCampaign? item]) async {
    if (!_current || _busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationCampaignEditor(
          repository: widget.repository,
          sessions: widget.sessions,
          campaign: item,
        ),
      ),
    );
    if (_current) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Yönetimi'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _current && !_busy
                ? () => _load(_page?.page ?? 0)
                : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: _current
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: AdminBrandButton(
                key: const Key('campaign-create'),
                onPressed: _busy ? null : _open,
                icon: Icons.add_rounded,
                label: 'Bildirim oluştur',
              ),
            )
          : null,
      body: !_current
          ? const Center(child: Text('Bildirim yönetim yetkisi gerekli.'))
          : _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _CampaignMessage(
              message: _error!,
              action: () => _load(),
              label: 'Yeniden dene',
            )
          : _page == null || _page!.items.isEmpty
          ? const _CampaignMessage(
              icon: Icons.notifications_none_rounded,
              title: 'İlk bildiriminle başla',
              message:
                  'Henüz bildirim planı yok. Alıcılarını seç, mesajını hazırla ve doğru zamanda paylaş.',
            )
          : RefreshIndicator(
              onRefresh: () => _load(_page!.page),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  AdminSectionCard(
                    title: 'Mesajların, doğru zamanda',
                    icon: Icons.notifications_active_outlined,
                    description:
                        'Taslaklarını hazırla; alıcıları ve gönderim takvimini tek yerden yönet.',
                    children: [
                      Text(
                        '${_page!.total} bildirim planı',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text('Taslaklar sen planlayana kadar gönderilmez.'),
                    ],
                  ),
                  for (final item in _page!.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CollabGradientFrame(
                        radius: 20,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey('campaign-${item.id}'),
                            onTap: () => _open(item),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _CampaignStatusBadge(status: item.status),
                                      Text(
                                        campaignRepeatLabels[item
                                            .input
                                            .repeat]!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.input.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.chevron_right_rounded),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    item.input.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 9),
                                    child: Divider(),
                                  ),
                                  Text(
                                    '${campaignDateLabel(item.input.localStartsAt)} · ${item.input.zoneId}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${item.stats['notifications']} bildirim oluşturuldu',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _page!.page > 0
                            ? () => _load(_page!.page - 1)
                            : null,
                        child: const Text('Önceki'),
                      ),
                      Text('Sayfa ${_page!.page + 1} · ${_page!.total} kayıt'),
                      TextButton(
                        onPressed: _page!.hasMore
                            ? () => _load(_page!.page + 1)
                            : null,
                        child: const Text('Sonraki'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _CampaignMessage extends StatelessWidget {
  const _CampaignMessage({
    required this.message,
    this.action,
    this.label,
    this.title,
    this.icon = Icons.info_outline_rounded,
  });
  final String message;
  final String? title;
  final IconData icon;
  final VoidCallback? action;
  final String? label;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CollabGradientFrame(
            highlighted: true,
            radius: 24,
            padding: const EdgeInsets.all(22),
            child: Icon(icon, size: 36, color: AppColors.accentText),
          ),
          const SizedBox(height: 24),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton(onPressed: action, child: Text(label!)),
            ),
        ],
      ),
    ),
  );
}

class _CampaignStatusBadge extends StatelessWidget {
  const _CampaignStatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        campaignStatusLabels[status] ?? status,
        style: TextStyle(
          color: status == 'SCHEDULED'
              ? AppColors.accentText
              : theme.colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
