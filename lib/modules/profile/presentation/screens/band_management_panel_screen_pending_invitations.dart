part of 'band_management_panel_screen.dart';

/// Private read-only list. Pending invitations never become member entities.
class _BandPendingInvitationsSliver extends StatefulWidget {
  const _BandPendingInvitationsSliver({
    required this.profile,
    required this.canManage,
    required this.enabled,
    required this.sessionManager,
    required this.session,
    required this.repository,
  });
  final BandProfile profile;
  final bool canManage;
  final bool enabled;
  final AuthSessionManager? sessionManager;
  final AuthSession? session;
  final BandRepository repository;

  @override
  State<_BandPendingInvitationsSliver> createState() =>
      _BandPendingInvitationsSliverState();
}

class _BandPendingInvitationsSliverState
    extends State<_BandPendingInvitationsSliver> {
  static const _pageSize = 20;
  final List<BandPendingInvitation> _items = [];
  int _generation = 0;
  int _nextPage = 0;
  int _total = 0;
  bool _loading = false;
  bool _hasNext = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.canManage) unawaited(_load(reset: true));
  }

  @override
  void didUpdateWidget(covariant _BandPendingInvitationsSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.canManage) {
      ++_generation;
      _clear();
    } else if (!oldWidget.canManage ||
        !identical(oldWidget.session, widget.session) ||
        !identical(oldWidget.profile, widget.profile)) {
      unawaited(_load(reset: true));
    }
  }

  @override
  void dispose() {
    ++_generation;
    super.dispose();
  }

  void _clear() {
    _items.clear();
    _nextPage = 0;
    _total = 0;
    _loading = false;
    _hasNext = false;
    _error = null;
  }

  Future<void> _load({required bool reset}) async {
    final session = widget.session;
    if (!mounted ||
        !widget.canManage ||
        session == null ||
        !identical(widget.sessionManager?.session, session) ||
        (!reset && (_loading || !_hasNext))) {
      return;
    }
    final generation = reset ? ++_generation : _generation;
    final bandId = widget.profile.id;
    final page = reset ? 0 : _nextPage;
    bool current() =>
        mounted &&
        generation == _generation &&
        widget.canManage &&
        widget.profile.id == bandId &&
        identical(widget.sessionManager?.session, session);
    setState(() {
      if (reset) _clear();
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.getPendingInvitations(
        bandId: bandId,
        page: page,
        size: _pageSize,
        expectedSessionKey: session.userId!.trim(),
      );
      if (!current()) return;
      final data = result.data;
      if (!result.isSuccess || data == null) {
        if (const {
          '9217',
          '401',
          '403',
          'unauthorized',
          'forbidden',
        }.contains(result.error?.code)) {
          _clear();
        }
        setState(() => _error = 'Bekleyen davetler yüklenemedi.');
        return;
      }
      if (data.page != page ||
          data.size != _pageSize ||
          data.totalElements < 0 ||
          data.items.length > _pageSize ||
          (data.hasNext && data.items.isEmpty) ||
          data.items.any(
            (item) =>
                item.userId.trim().isEmpty || item.username.trim().isEmpty,
          )) {
        throw const FormatException('Invalid pending page');
      }
      final ids = _items.map((item) => item.userId).toSet();
      if (!reset &&
          (data.totalElements != _total ||
              data.items.any((item) => ids.contains(item.userId)))) {
        // Acceptance or a new invitation can shift an offset page boundary.
        // Restart once at page zero instead of retaining an accepted invite or
        // silently skipping a still-pending person. A first page never recurses.
        await _load(reset: true);
        return;
      }
      final activeIds = widget.profile.members
          .where((member) => member.status.trim().toUpperCase() == 'ACTIVE')
          .map((member) => member.userId.trim())
          .toSet();
      setState(() {
        for (final item in data.items) {
          if (!activeIds.contains(item.userId) && ids.add(item.userId)) {
            _items.add(item);
          }
        }
        _total = data.totalElements;
        _nextPage = page + 1;
        _hasNext = data.hasNext && _nextPage * _pageSize <= 100000;
      });
    } catch (_) {
      if (current()) setState(() => _error = 'Bekleyen davetler yüklenemedi.');
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  void _requestNext() {
    if (!mounted ||
        !widget.enabled ||
        _loading ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    unawaited(_load(reset: _nextPage == 0));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canManage ||
        (_items.isEmpty && !_hasNext && !_loading && _error == null)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final colors = Theme.of(context).colorScheme;
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          sliver: SliverToBoxAdapter(
            child: Row(
              key: const Key('band-pending-section'),
              children: [
                Expanded(
                  child: Text(
                    'Bekleyen Davetler',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_total > 0) ...[
                  const SizedBox(width: 12),
                  Text(
                    '$_total',
                    key: const Key('band-pending-count'),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) => _PendingInvitationCard(
              key: ValueKey('band-pending-${_items[index].userId}'),
              invitation: _items[index],
            ),
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              key: Key('band-pending-loading'),
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (_error != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  TextButton(
                    key: const Key('band-pending-retry'),
                    onPressed: widget.enabled ? _requestNext : null,
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          )
        else if (_hasNext)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            sliver: SliverToBoxAdapter(
              child: TextButton(
                key: const Key('band-pending-more'),
                onPressed: widget.enabled ? _requestNext : null,
                child: const Text('Daha fazla göster'),
              ),
            ),
          ),
      ],
    );
  }
}

class _PendingInvitationCard extends StatelessWidget {
  const _PendingInvitationCard({super.key, required this.invitation});
  final BandPendingInvitation invitation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          _MemberAvatar(
            imageUrl: _resolveMemberAvatarUrl(invitation.profilePictureUrl),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const _GradientIcon(icon: Icons.schedule_rounded, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Onay bekliyor',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
