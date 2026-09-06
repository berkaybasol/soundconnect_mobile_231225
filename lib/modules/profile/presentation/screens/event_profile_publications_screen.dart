import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/widgets/event_poster_fallback.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/entities/event_performer_request.dart';
import '../../domain/entities/event_profile_publication.dart';
import '../../domain/event_profile_publication_repository.dart';

class EventProfilePublicationsScreen extends StatefulWidget {
  const EventProfilePublicationsScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    this.repository,
    this.sessionKeyProvider,
    this.embedded = false,
    this.onBusyChanged,
    this.showPeriods = false,
  });

  final EventPerformerTargetType targetType;
  final String targetId;
  final EventProfilePublicationRepository? repository;
  final String? Function()? sessionKeyProvider;
  final bool embedded;
  final ValueChanged<bool>? onBusyChanged;
  final bool showPeriods;

  @override
  State<EventProfilePublicationsScreen> createState() =>
      _EventProfilePublicationsScreenState();
}

class _EventProfilePublicationsScreenState
    extends State<EventProfilePublicationsScreen>
    with WidgetsBindingObserver {
  EventProfilePublicationRepository? _repository;
  AuthSessionManager? _manager;
  String? _loadedSession;
  int _generation = 0;
  int _page = 0;
  bool _hasNext = false;
  bool _loading = true;
  String? _error;
  List<EventProfilePublication> _items = const [];
  final Set<String> _updating = {};
  late EventProfilePublicationPeriod _period;

  String? get _session {
    if (widget.sessionKeyProvider != null) return widget.sessionKeyProvider!();
    final session = _manager?.session;
    if (session == null || !session.isAuthenticated || !session.isActive) {
      return null;
    }
    return '${session.userId}:${session.token}:${session.accountStatus}';
  }

  @override
  void initState() {
    super.initState();
    _period = widget.showPeriods
        ? EventProfilePublicationPeriod.current
        : EventProfilePublicationPeriod.all;
    WidgetsBinding.instance.addObserver(this);
    _bind();
  }

  void _bind() {
    _manager?.removeListener(_sessionChanged);
    _manager = serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null;
    _manager?.addListener(_sessionChanged);
    _repository =
        widget.repository ??
        (serviceLocator.isRegistered<EventProfilePublicationRepository>()
            ? serviceLocator<EventProfilePublicationRepository>()
            : null);
    unawaited(_load(0, force: true));
  }

  @override
  void didUpdateWidget(covariant EventProfilePublicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showPeriods != widget.showPeriods) {
      _period = widget.showPeriods
          ? EventProfilePublicationPeriod.current
          : EventProfilePublicationPeriod.all;
    }
    if (oldWidget.targetType != widget.targetType ||
        oldWidget.showPeriods != widget.showPeriods ||
        oldWidget.targetId != widget.targetId ||
        oldWidget.repository != widget.repository ||
        oldWidget.sessionKeyProvider != widget.sessionKeyProvider) {
      _bind();
    }
  }

  void _sessionChanged() {
    if (!mounted || _loadedSession == _session) return;
    ++_generation;
    setState(() {
      _items = const [];
      _loading = false;
      _hasNext = false;
      _updating.clear();
      _error = 'Oturum değişti. Bu sayfayı yeniden aç.';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load(0));
  }

  @override
  void dispose() {
    ++_generation;
    _manager?.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _matches(EventProfilePublication item) =>
      item.targetType == widget.targetType &&
      item.targetId == widget.targetId.trim();

  Future<void> _load(int page, {bool force = false}) async {
    if (!mounted || (!force && (_loading || _updating.isNotEmpty))) return;
    final generation = ++_generation;
    final session = _session;
    final repository = _repository;
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
      _updating.clear();
      _hasNext = false;
      _loadedSession = session;
    });
    if (session == null ||
        session.trim().isEmpty ||
        repository == null ||
        widget.targetId.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Profil etkinliklerine erişilemiyor. Sayfayı yeniden aç.';
      });
      return;
    }
    try {
      final result = await repository.listMine(
        targetType: widget.targetType,
        targetId: widget.targetId.trim(),
        page: page,
        size: 20,
        period: _period,
      );
      if (!mounted || generation != _generation) return;
      if (session != _session) {
        _sessionChanged();
        return;
      }
      final data = result.data;
      if (!result.isSuccess || data == null) {
        setState(() {
          _loading = false;
          _error =
              result.error?.message ?? 'Etkinlikler alınamadı. Tekrar dene.';
        });
        return;
      }
      if (data.page != page || data.items.any((item) => !_matches(item))) {
        setState(() {
          _loading = false;
          _error = 'Etkinliklerin ait olduğu profil doğrulanamadı.';
        });
        return;
      }
      if (data.isOutOfRange && page > 0) {
        await _load(0, force: true);
        return;
      }
      setState(() {
        _loading = false;
        _page = page;
        _items = List.unmodifiable(data.items);
        _hasNext = data.hasNext;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      if (session != _session) {
        _sessionChanged();
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Etkinlikler alınamadı. Tekrar dene.';
      });
    }
  }

  Future<void> _setVisible(EventProfilePublication item) async {
    if (!mounted) return;
    final repository = _repository;
    if (repository == null ||
        (widget.showPeriods &&
            _period == EventProfilePublicationPeriod.past &&
            !item.visible) ||
        _loading ||
        _updating.isNotEmpty ||
        !_matches(item) ||
        !_items.any(
          (current) =>
              current.eventId == item.eventId &&
              current.version == item.version &&
              current.visible == item.visible,
        ) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final session = _session;
    if (session == null || session != _loadedSession) {
      _sessionChanged();
      return;
    }
    final generation = _generation;
    setState(() => _updating.add(item.eventId));
    widget.onBusyChanged?.call(true);
    try {
      final result = await repository.setVisible(
        eventId: item.eventId,
        targetType: item.targetType,
        targetId: item.targetId,
        visible: !item.visible,
        version: item.version,
      );
      if (!mounted || generation != _generation) return;
      if (session != _session) {
        _sessionChanged();
        return;
      }
      final updated = result.data;
      if (result.isSuccess &&
          updated != null &&
          _matches(updated) &&
          updated.eventId == item.eventId &&
          updated.visible == !item.visible &&
          updated.version > item.version) {
        setState(() {
          _updating.remove(item.eventId);
          _items = List.unmodifiable(
            _items.map(
              (value) => value.eventId == item.eventId ? updated : value,
            ),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updated.visible
                  ? _period == EventProfilePublicationPeriod.future
                        ? 'Profilinde gösterim tercihin kaydedildi.'
                        : 'Etkinlik profilinde gösteriliyor.'
                  : 'Etkinlik profilinden gizlendi. Katılım onayın değişmedi.',
            ),
          ),
        );
      } else {
        // A lost reply or version conflict is not an invitation to replay a write.
        // Re-read server state before enabling another visibility decision.
        final message =
            result.error?.message ??
            'Değişiklik doğrulanamadı. Güncel durum yenileniyor.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        await _load(_page, force: true);
      }
    } catch (_) {
      if (!mounted || generation != _generation) return;
      if (session != _session) {
        _sessionChanged();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Değişiklik doğrulanamadı. Güncel durum yenileniyor.'),
        ),
      );
      await _load(_page, force: true);
    } finally {
      if (mounted) widget.onBusyChanged?.call(false);
    }
  }

  Widget _periodSelector(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          for (final entry in [
            (EventProfilePublicationPeriod.current, 'Bu Haftaki'),
            (EventProfilePublicationPeriod.future, 'Gelecek'),
            (EventProfilePublicationPeriod.past, 'Geçmiş'),
          ])
            Expanded(
              child: Semantics(
                selected: _period == entry.$1,
                child: _period == entry.$1
                    ? GradientOutlineButton(
                        key: ValueKey('event-period-${entry.$1.name}'),
                        label: entry.$2,
                        horizontalPadding: 6,
                        strokeWidth: .8,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        onPressed: _updating.isEmpty ? () {} : null,
                      )
                    : TextButton(
                        key: ValueKey('event-period-${entry.$1.name}'),
                        onPressed: _updating.isEmpty
                            ? () => _selectPeriod(entry.$1)
                            : null,
                        child: Text(
                          entry.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
            ),
        ],
      ),
    ),
  );

  void _selectPeriod(EventProfilePublicationPeriod period) {
    if (!mounted ||
        _updating.isNotEmpty ||
        period == _period ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _period = period);
    unawaited(_load(0, force: true));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Etkinliklerim'),
              centerTitle: true,
              bottom: widget.showPeriods
                  ? PreferredSize(
                      preferredSize: Size.fromHeight(
                        (MediaQuery.textScalerOf(context).scale(14) + 48).clamp(
                          72.0,
                          double.infinity,
                        ),
                      ),
                      child: _periodSelector(context),
                    )
                  : null,
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(0),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _period == EventProfilePublicationPeriod.past
                    ? 'Katılımı onaylanan geçmiş etkinlikler burada saklanır.'
                    : widget.targetType == EventPerformerTargetType.band
                    ? 'Grup profilinde hangi etkinliklerin görüneceğini seç. Üyelerin kişisel tercihleri değişmez.'
                    : 'Profilinde hangi etkinliklerin görüneceğini seç. Bu tercih katılımını değiştirmez.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 22),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null) ...[
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _load(0),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar dene'),
                ),
              ] else if (_items.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    widget.showPeriods
                        ? 'Bu bölümde etkinlik yok.'
                        : 'Henüz yönetebileceğin bir etkinlik yok. Katılımı onaylanan etkinlikler burada görünür.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                for (final item in _items) ...[
                  _PublicationCard(
                    item: item,
                    period: _period,
                    processing: _updating.contains(item.eventId),
                    enabled: _updating.isEmpty,
                    onToggle: () => _setVisible(item),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
              if (!_loading && _error == null && (_page > 0 || _hasNext))
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _page > 0 && _updating.isEmpty
                          ? () => _load(_page - 1)
                          : null,
                      child: const Text('Önceki'),
                    ),
                    Text('${_page + 1}'),
                    TextButton(
                      onPressed: _hasNext && _updating.isEmpty
                          ? () => _load(_page + 1)
                          : null,
                      child: const Text('Sonraki'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicationCard extends StatelessWidget {
  const _PublicationCard({
    required this.item,
    required this.processing,
    required this.enabled,
    required this.onToggle,
    this.period = EventProfilePublicationPeriod.all,
  });
  final EventProfilePublication item;
  final bool processing;
  final bool enabled;
  final VoidCallback onToggle;
  final EventProfilePublicationPeriod period;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = item.eventDate;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    final time = item.startTime.length >= 5
        ? item.startTime.substring(0, 5)
        : item.startTime;
    Widget fallback(BuildContext context) =>
        EventPosterFallback(title: item.eventTitle, showDetails: false);
    return Container(
      key: ValueKey('publication-${item.eventId}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 66,
                  height: 88,
                  child: AppCachedNetworkImage(
                    imageUrl: item.posterImage,
                    cacheWidth: 198,
                    cacheHeight: 264,
                    placeholderBuilder: fallback,
                    errorBuilder: fallback,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.eventTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.venueName,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$dateText · $time',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.performerName,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            period == EventProfilePublicationPeriod.past
                ? 'Geçmiş etkinlik'
                : !item.visible
                ? 'Profilinde gizli'
                : period == EventProfilePublicationPeriod.future
                ? 'Profilinde gösterilecek'
                : 'Profilinde gösteriliyor',
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (period != EventProfilePublicationPeriod.past || item.visible) ...[
            const SizedBox(height: 14),
            GradientOutlineButton(
              key: ValueKey('toggle-publication-${item.eventId}'),
              label: item.visible ? 'Profilimden gizle' : 'Profilimde göster',
              leading: Icon(
                item.visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              strokeWidth: .8,
              loading: processing,
              onPressed: enabled ? onToggle : null,
            ),
          ],
        ],
      ),
    );
  }
}
