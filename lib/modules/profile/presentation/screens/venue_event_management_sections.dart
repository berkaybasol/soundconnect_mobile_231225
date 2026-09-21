part of 'venue_weekly_calendar_editor_screen.dart';

enum _EventGroup { thisWeek, future, past }

extension _VenueEventManagementSections
    on _VenueWeeklyCalendarEditorScreenState {
  Widget _buildEditor(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Etkinlik Yönetimi'),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: 'Etkinlikleri yenile',
            onPressed: _loading || _plansLoading || _saving
                ? null
                : _refreshManagement,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop || _saving) return;
          Navigator.of(context).pop(_changed);
        },
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                    child: _managementTabs(theme),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _managementTab,
                      children: [
                        _managementScroll(
                          storageKey: 'venue-management-events-scroll',
                          loading: _loading,
                          children: _buildCalendarContent(),
                        ),
                        _managementScroll(
                          storageKey: 'venue-management-plans-scroll',
                          loading: _plansLoading,
                          children: _buildPlanContent(theme),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _managementTabs(ThemeData theme) {
    final scheme = theme.colorScheme;
    final stacked =
        MediaQuery.sizeOf(context).width < 440 &&
        MediaQuery.textScalerOf(
              context,
            ).scale(theme.textTheme.labelLarge?.fontSize ?? 14) >
            20;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Flex(
        direction: stacked ? Axis.vertical : Axis.horizontal,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: stacked
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        children: [
          for (final tab in [
            (0, 'Etkinlikler', Icons.calendar_today_outlined, 'events'),
            (1, 'Planlar', Icons.event_repeat_rounded, 'plans'),
          ])
            _managementTabSlot(
              stacked: stacked,
              child: Semantics(
                selected: _managementTab == tab.$1,
                button: true,
                child: GradientOutline(
                  enabled: _managementTab == tab.$1,
                  radius: 10,
                  strokeWidth: 1,
                  child: Material(
                    color: _managementTab == tab.$1
                        ? scheme.surfaceContainerHighest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('venue-management-${tab.$4}-tab'),
                      onTap: () => _selectManagementTab(tab.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 13,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tab.$3,
                              size: 18,
                              color: _managementTab == tab.$1
                                  ? AppColors.brandGradient[2]
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                tab.$2,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: _managementTab == tab.$1
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _managementTabSlot({required bool stacked, required Widget child}) =>
      stacked ? child : Expanded(child: child);

  Widget _managementScroll({
    required String storageKey,
    required bool loading,
    required List<Widget> children,
  }) => Stack(
    children: [
      RefreshIndicator(
        color: AppColors.brandGradient[2],
        onRefresh: _saving ? () async {} : _refreshManagement,
        child: CustomScrollView(
          key: PageStorageKey(storageKey),
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              sliver: SliverList(delegate: SliverChildListDelegate(children)),
            ),
          ],
        ),
      ),
      if (loading)
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(minHeight: 2),
        ),
    ],
  );

  List<Widget> _profileHeading() => [
    VenueCalendarProfileHeader(
      imageUrl: _profileImage,
      venueName: _profileName,
      locationLabel: _locationLabel,
    ),
    const SizedBox(height: 22),
  ];

  List<Widget> _buildCalendarContent() {
    final now = DateTime.now();
    final upcoming = _upcomingEvents;
    final thisWeek = upcoming
        .where((event) => !isVenueEventBeyondWeek(event.eventDate, now: now))
        .toList();
    final future = upcoming
        .where((event) => isVenueEventBeyondWeek(event.eventDate, now: now))
        .toList();
    return [
      ..._profileHeading(),
      VenueCalendarCreateButton(
        onTap: _loading || !_ownsSession ? null : _createEvent,
        saving: _saving,
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        VenueCalendarErrorCard(message: _error!, onRetry: _refreshManagement),
      ],
      const SizedBox(height: 20),
      if (_loading && _expandedEventGroups == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 52),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_expandedEventGroups != null)
        for (final section in [
          (
            _EventGroup.thisWeek,
            'Bu Haftaki Etkinlikler',
            'Bu hafta etkinlik yok.',
            thisWeek,
            'this-week',
          ),
          (
            _EventGroup.future,
            'Gelecek Etkinlikler',
            'İleri tarihli etkinlik yok.',
            future,
            'future',
          ),
          (
            _EventGroup.past,
            'Geçmiş Etkinlikler',
            'Henüz geçmiş etkinlik yok.',
            _historyEvents,
            'past',
          ),
        ]) ...[
          _ManagementAccordionHeader(
            key: ValueKey('venue-events-${section.$5}'),
            title: section.$2,
            count: section.$1 == _EventGroup.past
                ? _pastEventCount
                : section.$4.length,
            expanded: _expandedEventGroups!.contains(section.$1),
            onTap: () => _toggleEventGroup(section.$1),
          ),
          if (_expandedEventGroups!.contains(section.$1)) ...[
            const SizedBox(height: 12),
            if (section.$1 == _EventGroup.past)
              ..._historyContent()
            else if (section.$4.isEmpty)
              VenueCalendarEmptyState(
                history: section.$1 == _EventGroup.past,
                message: section.$3,
              )
            else
              for (final item in section.$4) ...[
                _managementEventCard(
                  item,
                  history: section.$1 == _EventGroup.past,
                ),
                const SizedBox(height: 10),
              ],
          ],
          const SizedBox(height: 14),
        ],
    ];
  }

  List<Widget> _historyContent() {
    final theme = appSurfaceTheme(Theme.of(context));
    final enabled = !_loading && !_saving && !_historyLoading && _ownsSession;
    return [
      if (_historyLoaded && _historyEvents.isEmpty && _historyError == null)
        const VenueCalendarEmptyState(
          history: true,
          message: 'Henüz geçmiş etkinlik yok.',
        ),
      for (final item in _historyEvents) ...[
        _managementEventCard(item, history: true),
        const SizedBox(height: 10),
      ],
      if (_historyError != null) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text(
            _historyError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
        _HistoryLoadButton(
          key: const ValueKey('venue-events-history-retry'),
          label: 'Tekrar dene',
          onTap: enabled ? () => _loadHistory(reset: !_historyLoaded) : null,
        ),
      ] else if (_historyHasNext || _historyLoading)
        _HistoryLoadButton(
          key: const ValueKey('venue-events-history-more'),
          label: _historyLoading ? 'Yükleniyor…' : 'Daha fazla yükle',
          loading: _historyLoading,
          onTap: enabled ? _loadHistory : null,
        ),
    ];
  }

  Widget _managementEventCard(
    VenueOwnerEventItem item, {
    required bool history,
  }) {
    if (history) {
      return VenueCalendarPastEventCard(
        posterImage: item.posterImage,
        title: item.title,
        dateLabel: formatVenueEventDate(item.eventDate),
        timeLabel: _eventTimeLabel(item),
        performerName: item.performerName,
        onTap: () => _openEvent(item),
        saving: _saving || _loading || _historyLoading,
        onDelete: _canDelete(item) ? () => _confirmDeleteEvent(item) : null,
        onCopy: _planRepository == null ? null : () => _copyEvent(item),
      );
    }
    return VenueCalendarEventCard(
      posterImage: item.posterImage,
      title: item.title,
      dateLabel: formatVenueEventDate(item.eventDate),
      timeLabel: _eventTimeLabel(item),
      performerName: item.performerName,
      onTap: () => _openEvent(item),
      saving: _saving || _loading,
      onDelete: _canDelete(item) ? () => _confirmDeleteEvent(item) : null,
      onCopy: _planRepository == null ? null : () => _copyEvent(item),
    );
  }

  List<Widget> _buildPlanContent(ThemeData theme) {
    final plans = _plans?.items ?? <EventPlan>[];
    final active = plans.where((plan) => plan.active).toList();
    final history = plans.where((plan) => !plan.active).toList();
    final enabled =
        !_saving &&
        !_loading &&
        !_plansLoading &&
        _ownsSession &&
        _planRepository != null;
    return [
      ..._profileHeading(),
      GradientOutline(
        radius: 10,
        child: Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('venue-management-create-plan'),
            onTap: enabled ? () => _createEvent(asPlan: true) : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Yeni plan oluştur',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Tekrarlanan etkinliklerinin günlerini ve takvimini buradan yönet.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      if (_plansError != null)
        VenueCalendarErrorCard(
          message: _plansError!,
          onRetry: _refreshManagement,
        ),
      if (_plansLoading && _plans == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 52),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_plansError == null) ...[
        if (plans.isEmpty)
          VenueCalendarEmptyState(
            history: false,
            message: _planRepository == null
                ? 'Planlar şu anda kullanılamıyor.'
                : 'Henüz etkinlik planı yok.',
          )
        else ...[
          if (active.isNotEmpty) ...[
            Text(
              'Aktif planlar',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final plan in active) _ownerPlanCard(plan),
            const SizedBox(height: 10),
          ],
          if (history.isNotEmpty) ...[
            _ManagementAccordionHeader(
              key: const ValueKey('venue-plans-history'),
              title: 'Geçmiş planlar',
              // A page count must not be presented as the overall plan count.
              count: _plans!.page == 0 && !_plans!.hasNext
                  ? history.length
                  : null,
              expanded: _planHistoryExpanded,
              onTap: _togglePlanHistory,
            ),
            if (_planHistoryExpanded) ...[
              const SizedBox(height: 12),
              for (final plan in history) _ownerPlanCard(plan),
            ],
          ],
        ],
      ],
      if (_plans != null && (_plans!.page > 0 || _plans!.hasNext)) ...[
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: TextButton(
                onPressed: !enabled || _plans!.page == 0
                    ? null
                    : () => _loadPlans(page: _plans!.page - 1),
                child: const Text('Önceki planlar'),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: !enabled || !_plans!.hasNext || _plans!.page >= 100
                    ? null
                    : () => _loadPlans(page: _plans!.page + 1),
                child: const Text('Sonraki planlar'),
              ),
            ),
          ],
        ),
      ],
    ];
  }
}

class _HistoryLoadButton extends StatelessWidget {
  const _HistoryLoadButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GradientOutline(
        radius: 10,
        strokeWidth: 1,
        child: Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading) ...[
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandGradient[2],
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagementAccordionHeader extends StatelessWidget {
  const _ManagementAccordionHeader({
    super.key,
    required this.title,
    this.count,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final int? count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      expanded: expanded,
      child: Material(
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandGradient[2].withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: AppColors.brandGradient[2],
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
