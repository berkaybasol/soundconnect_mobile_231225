import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/venue_analytics_repository.dart';
import '../widgets/venue_analytics_reporting.dart';
import '../widgets/venue_analytics_reporting_scope.dart';

class VenueAnalyticsScreen extends StatelessWidget {
  const VenueAnalyticsScreen({
    super.key,
    required this.venueId,
    required this.venueName,
    required this.ownerUserId,
    this.eventId,
    this.eventTitle,
    this.repository,
    this.sessions,
    this.initialDays = 30,
  });
  final String venueId;
  final String venueName;
  final String ownerUserId;
  final String? eventId;
  final String? eventTitle;
  final VenueAnalyticsRepository? repository;
  final AuthSessionManager? sessions;
  final int initialDays;
  @override
  Widget build(BuildContext context) =>
      !VenueAnalyticsReportingScope.of(context).enabled
      ? const _AnalyticsComingSoon()
      : _AnalyticsContent(
          venueId: venueId,
          venueName: venueName,
          ownerUserId: ownerUserId,
          eventId: eventId,
          eventTitle: eventTitle,
          repository: repository,
          sessions: sessions,
          mode: eventId == null ? _Mode.overview : _Mode.event,
          initialDays: initialDays,
        );
}

class _AnalyticsComingSoon extends StatelessWidget {
  const _AnalyticsComingSoon();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('İstatistikler'), centerTitle: true),
    body: const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrandGradientIcon.social(Icons.insights_rounded, size: 42),
            SizedBox(height: 20),
            Text(
              'Yakında',
              key: Key('analytics-reporting-coming-soon'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text(
              'Mekan istatistikleri yakında kullanıma açılacak.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A navigation affordance only: no counts or private requests until opened.
class VenueAnalyticsLink extends StatefulWidget {
  const VenueAnalyticsLink({
    super.key,
    required this.venueId,
    required this.venueName,
    required this.ownerUserId,
    this.eventId,
    this.eventTitle,
    this.repository,
    this.sessions,
  });
  final String venueId;
  final String venueName;
  final String ownerUserId;
  final String? eventId;
  final String? eventTitle;
  final VenueAnalyticsRepository? repository;
  final AuthSessionManager? sessions;
  @override
  State<VenueAnalyticsLink> createState() => _VenueAnalyticsLinkState();
}

bool _canReadAnalytics(
  AuthSession? session,
  String venueId,
  String ownerUserId,
  String? eventId,
) =>
    venueId.trim().isNotEmpty &&
    ownerUserId.trim().isNotEmpty &&
    (eventId == null || eventId.trim().isNotEmpty) &&
    session?.isAuthenticated == true &&
    session?.isActive == true &&
    session!.hasAnyRole(const ['ROLE_VENUE', 'VENUE']) &&
    session.userId?.trim() == ownerUserId.trim();

class _VenueAnalyticsLinkState extends State<VenueAnalyticsLink> {
  AuthSessionManager? _sessions;
  bool _opening = false;

  bool get _allowed =>
      mounted &&
      VenueAnalyticsReportingScope.read(context).enabled &&
      _canReadAnalytics(
        _sessions?.session,
        widget.venueId,
        widget.ownerUserId,
        widget.eventId,
      );

  void _bindSession() {
    _sessions =
        widget.sessions ??
        (serviceLocator.isRegistered<AuthSessionManager>()
            ? serviceLocator<AuthSessionManager>()
            : null);
    _sessions?.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _bindSession();
  }

  @override
  void didUpdateWidget(covariant VenueAnalyticsLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions != widget.sessions) {
      _sessions?.removeListener(_sessionChanged);
      _bindSession();
    }
  }

  @override
  void dispose() {
    _sessions?.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _open() async {
    if (!mounted ||
        !_allowed ||
        _opening ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    // Capture this entity before pushing; a later parent rebuild cannot retarget it.
    final page = VenueAnalyticsScreen(
      venueId: widget.venueId,
      venueName: widget.venueName,
      ownerUserId: widget.ownerUserId,
      eventId: widget.eventId,
      eventTitle: widget.eventTitle,
      repository: widget.repository,
      sessions: _sessions,
    );
    setState(() => _opening = true);
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!VenueAnalyticsReportingScope.of(context).enabled) {
      return const SizedBox.shrink();
    }
    if (!_allowed) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        key: const Key('analytics-open-link'),
        onPressed: _opening ? null : _open,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandGradientIcon.social(Icons.insights_rounded, size: 18),
            const SizedBox(width: 7),
            const Flexible(
              child: Text(
                'İstatistikleri gör',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

enum _Mode { overview, event }

class _AnalyticsContent extends StatefulWidget {
  const _AnalyticsContent({
    required this.venueId,
    this.eventId,
    this.eventTitle,
    required this.venueName,
    required this.ownerUserId,
    required this.repository,
    required this.sessions,
    required this.mode,
    required this.initialDays,
  });
  final String venueId;
  final String? eventId;
  final String? eventTitle;
  final String venueName;
  final String ownerUserId;
  final VenueAnalyticsRepository? repository;
  final AuthSessionManager? sessions;
  final _Mode mode;
  final int initialDays;
  @override
  State<_AnalyticsContent> createState() => _AnalyticsContentState();
}

class _AnalyticsContentState extends State<_AnalyticsContent> {
  AuthSessionManager? _sessions;
  VenueAnalyticsSummary? _summary;
  final List<VenueAnalyticsEvent> _events = [];
  String? _summaryError;
  String? _eventsError;
  bool _loading = false;
  bool _loadingEvents = false;
  bool _hasNext = false;
  int _days = 30;
  int _page = -1;
  int _epoch = 0;
  int _eventsEpoch = 0;
  VenueAnalyticsSort _sort = VenueAnalyticsSort.date;
  bool _openingEvent = false;

  VenueAnalyticsRepository? get _repository =>
      widget.repository ??
      (serviceLocator.isRegistered<VenueAnalyticsRepository>()
          ? serviceLocator<VenueAnalyticsRepository>()
          : null);
  bool get _allowed =>
      mounted &&
      VenueAnalyticsReportingScope.read(context).enabled &&
      _canReadAnalytics(
        _sessions?.session,
        widget.venueId,
        widget.ownerUserId,
        widget.eventId,
      );

  bool _current(int epoch, AuthSession session) =>
      mounted &&
      epoch == _epoch &&
      _allowed &&
      identical(session, _sessions?.session);

  @override
  void initState() {
    super.initState();
    _days = [7, 30, 90].contains(widget.initialDays) ? widget.initialDays : 30;
    _bindSession();
    unawaited(_reload());
  }

  void _bindSession() {
    _sessions =
        widget.sessions ??
        (serviceLocator.isRegistered<AuthSessionManager>()
            ? serviceLocator<AuthSessionManager>()
            : null);
    _sessions?.addListener(_sessionChanged);
  }

  void _sessionChanged() => unawaited(_reload());
  @override
  void didUpdateWidget(covariant _AnalyticsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions != widget.sessions) {
      _sessions?.removeListener(_sessionChanged);
      _bindSession();
    }
    if (oldWidget.venueId != widget.venueId ||
        oldWidget.eventId != widget.eventId ||
        oldWidget.ownerUserId != widget.ownerUserId ||
        oldWidget.repository != widget.repository ||
        oldWidget.sessions != widget.sessions) {
      unawaited(_reload());
    }
  }

  @override
  void dispose() {
    _epoch++;
    _sessions?.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final epoch = ++_epoch;
    _eventsEpoch++;
    setState(() {
      _summary = null;
      _events.clear();
      _summaryError = null;
      _eventsError = null;
      _page = -1;
      _hasNext = false;
      _loading = _allowed;
      _loadingEvents = false;
    });
    if (!_allowed) return;
    final session = _sessions!.session;
    await Future.wait<void>([
      _loadSummary(epoch, session),
      if (widget.mode == _Mode.overview) _loadEvents(epoch, session),
    ]);
  }

  Future<void> _loadSummary(int epoch, AuthSession session) async {
    try {
      final repository = _repository;
      if (repository == null) {
        throw StateError('Analytics repository unavailable');
      }
      final Result<VenueAnalyticsSummary> result;
      if (widget.mode == _Mode.event) {
        result = await repository.event(
          venueId: widget.venueId,
          eventId: widget.eventId!,
          expectedSessionKey: session.userId!,
          days: _days,
        );
      } else {
        result = await repository.summary(
          venueId: widget.venueId,
          expectedSessionKey: session.userId!,
          days: _days,
        );
      }
      if (!_current(epoch, session)) return;
      final data = result.data;
      final valid =
          result.isSuccess &&
          data != null &&
          data.venueId == widget.venueId.trim() &&
          data.eventId == widget.eventId?.trim() &&
          data.days == _days;
      setState(() {
        _loading = false;
        _summary = valid ? data : null;
        _summaryError = valid ? null : 'İstatistikler yüklenemedi.';
      });
    } catch (_) {
      if (!_current(epoch, session)) return;
      setState(() {
        _loading = false;
        _summaryError = 'İstatistikler yüklenemedi.';
      });
    }
  }

  Future<void> _loadEvents(int epoch, AuthSession session) async {
    if (!_current(epoch, session) ||
        _loadingEvents ||
        (_page >= 0 && !_hasNext)) {
      return;
    }
    final page = _page + 1;
    final eventsEpoch = _eventsEpoch;
    final sort = _sort;
    setState(() {
      _loadingEvents = true;
      _eventsError = null;
    });
    try {
      final repository = _repository;
      if (repository == null) {
        throw StateError('Analytics repository unavailable');
      }
      final result = await repository.events(
        venueId: widget.venueId,
        expectedSessionKey: session.userId!,
        days: _days,
        page: page,
        sort: sort,
      );
      if (!_current(epoch, session) || eventsEpoch != _eventsEpoch) return;
      final data = result.data;
      if (!result.isSuccess ||
          data == null ||
          data.page != page ||
          data.size != 20 ||
          data.sort != sort) {
        throw StateError('Invalid page');
      }
      final ids = _events.map((event) => event.eventId).toSet();
      setState(() {
        _events.addAll(data.items.where((event) => ids.add(event.eventId)));
        _page = page;
        _hasNext = data.hasNext;
        _loadingEvents = false;
      });
    } catch (_) {
      if (!_current(epoch, session) || eventsEpoch != _eventsEpoch) return;
      setState(() {
        _loadingEvents = false;
        _eventsError = 'Etkinlik listesi yüklenemedi.';
      });
    }
  }

  void _selectDays(int days) {
    if (!_allowed || days == _days) return;
    _days = days;
    unawaited(_reload());
  }

  void _selectSort(VenueAnalyticsSort? sort) {
    if (!_allowed || sort == null || sort == _sort) return;
    _eventsEpoch++;
    setState(() {
      _sort = sort;
      _page = -1;
      _events.clear();
      _hasNext = false;
      _loadingEvents = false;
      _eventsError = null;
    });
    unawaited(_loadEvents(_epoch, _sessions!.session));
  }

  Future<void> _openEvent(VenueAnalyticsEvent event) async {
    if (!mounted ||
        !_allowed ||
        _openingEvent ||
        ModalRoute.of(context)?.isCurrent != true ||
        !_events.any((current) => identical(current, event))) {
      return;
    }
    final screen = VenueAnalyticsScreen(
      venueId: widget.venueId,
      venueName: widget.venueName,
      ownerUserId: widget.ownerUserId,
      eventId: event.eventId,
      eventTitle: event.title,
      initialDays: _days,
      repository: _repository,
      sessions: _sessions,
    );
    _openingEvent = true;
    try {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
    } finally {
      _openingEvent = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const SizedBox.shrink();
    final full = widget.mode == _Mode.overview;
    final children = <Widget>[
      if (full) ...[
        Text(
          widget.venueName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Mekanının SoundConnect görünürlüğü',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
      ] else if (widget.eventTitle?.trim().isNotEmpty == true) ...[
        Text(
          widget.eventTitle!.trim(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
      ],
      Row(
        children: [
          Expanded(
            child: Text(
              full ? 'Genel bakış' : 'Etkinlik performansı',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            key: const Key('analytics-refresh'),
            tooltip: 'İstatistikleri yenile',
            onPressed: _loading || _loadingEvents
                ? null
                : () {
                    if (mounted && _allowed && !_loading && !_loadingEvents) {
                      unawaited(_reload());
                    }
                  },
            icon: const BrandGradientIcon.social(
              Icons.refresh_rounded,
              size: 21,
            ),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final days in [7, 30, 90]) _periodChoice(days),
        ],
      ),
      const SizedBox(height: 14),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(
              key: Key('analytics-summary-loading'),
            ),
          ),
        )
      else if (_summaryError != null)
        _retry(_summaryError!, () => unawaited(_reload()))
      else if (_summary != null) ...[
        _metrics(_summary!.metrics),
        const SizedBox(height: 12),
        Text(
          _summary!.trackingStartedAt == null
              ? 'Henüz ölçüm kaydı bulunmuyor.'
              : 'Ölçüm başlangıcı: ${_date(_istanbul(_summary!.trackingStartedAt!))}',
          key: const Key('analytics-tracking-start'),
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          '${_date(_summary!.fromDate)} – ${_date(_summary!.toDate)} · Türkiye saati',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        VenueAnalyticsDailyChart(points: _summary!.daily),
        const SizedBox(height: 16),
        VenueAnalyticsComparisonCard(
          comparison: _summary!.comparison,
          days: _days,
        ),
      ],
      if (full) ...[
        const SizedBox(height: 26),
        const Text(
          'Etkinlik karşılaştırması',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'Seçilen dönemdeki tekil ziyaretçiler. Etkinliklerin görünür kaldığı süre farklı olabilir.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<VenueAnalyticsSort>(
          key: ValueKey('analytics-event-sort-${_sort.name}'),
          initialValue: _sort,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sıralama'),
          dropdownColor: AppColors.navBlue,
          items: [
            for (final sort in VenueAnalyticsSort.values)
              DropdownMenuItem(
                value: sort,
                child: Text(switch (sort) {
                  VenueAnalyticsSort.date => 'En yeni',
                  VenueAnalyticsSort.reach => 'Tekil erişim',
                  VenueAnalyticsSort.detailViews => 'Detay ziyaretçisi',
                  VenueAnalyticsSort.profileVisits => 'Profil ziyaretçisi',
                }),
              ),
          ],
          onChanged: _selectSort,
        ),
        const SizedBox(height: 14),
        if (_events.isEmpty && !_loadingEvents && _eventsError == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Henüz listelenecek bir etkinlik yok.'),
          ),
        const SizedBox.shrink(key: Key('analytics-event-rows-anchor')),
        if (_loadingEvents)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                key: Key('analytics-events-loading'),
              ),
            ),
          )
        else if (_eventsError != null)
          _retry(
            _eventsError!,
            () => unawaited(_loadEvents(_epoch, _sessions!.session)),
          )
        else if (_hasNext)
          GradientOutlineButton(
            key: const Key('analytics-load-more'),
            label: 'Daha fazla göster',
            onPressed: () => unawaited(_loadEvents(_epoch, _sessions!.session)),
            strokeWidth: 1,
          ),
      ],
    ];
    final eventRowsIndex = children.indexWhere(
      (child) => child.key == const Key('analytics-event-rows-anchor'),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(full ? 'İstatistikler' : 'Etkinlik istatistikleri'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount:
                children.length + (eventRowsIndex < 0 ? 0 : _events.length - 1),
            itemBuilder: (context, index) {
              if (eventRowsIndex < 0 || index < eventRowsIndex) {
                return children[index];
              }
              final row = index - eventRowsIndex;
              if (row < _events.length) return _eventRow(_events[row]);
              return children[index - _events.length + 1];
            },
          ),
        ),
      ),
    );
  }

  Widget _periodChoice(int days) => Semantics(
    button: true,
    selected: _days == days,
    label: 'Son $days gün',
    onTap: () => _selectDays(days),
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _days == days
              ? LinearGradient(colors: AppColors.brandGradient)
              : null,
          color: _days == days ? null : AppColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(.8),
          child: Material(
            color: AppColors.navBlue,
            borderRadius: BorderRadius.circular(13.2),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('analytics-period-$days'),
              onTap: () => _selectDays(days),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  child: Text(
                    '$days gün',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _days == days
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: _days == days
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _metrics(VenueAnalyticsMetrics metrics) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 290 ||
          MediaQuery.textScalerOf(context).scale(13) > 19;
      final width = stacked
          ? constraints.maxWidth
          : (constraints.maxWidth - 10) / 2;
      final cards = <Widget>[
        SizedBox(
          width: width,
          child: _metric(
            'Tekil erişim',
            metrics.impressions,
            Icons.visibility_outlined,
            'impressions',
          ),
        ),
        SizedBox(
          width: width,
          child: _metric(
            'Detay ziyaretçisi',
            metrics.detailViews,
            Icons.touch_app_outlined,
            'detailViews',
          ),
        ),
        SizedBox(
          width: width,
          child: _metric(
            widget.mode == _Mode.event
                ? 'Etkinlikten profil ziyaretçisi'
                : 'Profil ziyaretçisi',
            metrics.profileVisits,
            Icons.storefront_outlined,
            'profileVisits',
          ),
        ),
        SizedBox(
          width: width,
          child: _surface(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandGradientIcon.social(Icons.groups_rounded, size: 21),
                const SizedBox(height: 10),
                const Text(
                  'Katılacaklar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Yakında',
                  key: const Key('analytics-going-soon'),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ];
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              cards[index],
            ],
          ],
        );
      }
      // Only four fixed summary cards are measured, keeping each pair aligned
      // without fixed heights that would clip accessibility text.
      return Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cards[0], const SizedBox(width: 10), cards[1]],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cards[2], const SizedBox(width: 10), cards[3]],
            ),
          ),
        ],
      );
    },
  );
  Widget _metric(String label, int value, IconData icon, String key) =>
      _surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrandGradientIcon.social(icon, size: 21),
            const SizedBox(height: 10),
            Text(
              _number(value),
              key: ValueKey('analytics-metric-$key'),
              softWrap: true,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
  Widget _eventRow(VenueAnalyticsEvent event) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      key: ValueKey('analytics-event-open-${event.eventId}'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => unawaited(_openEvent(event)),
      child: _surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    key: ValueKey('analytics-event-${event.eventId}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const BrandGradientIcon.social(
                  Icons.chevron_right_rounded,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              _date(event.eventDate),
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('${_number(event.metrics.impressions)} tekil erişim'),
                Text('${_number(event.metrics.detailViews)} detay'),
                Text('${_number(event.metrics.profileVisits)} profil ziyareti'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget _retry(String message, VoidCallback onRetry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Yeniden dene')),
      ],
    ),
  );
  Widget _surface(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.navBlue,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  String _number(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  DateTime _istanbul(DateTime value) =>
      value.toUtc().add(const Duration(hours: 3));
}
