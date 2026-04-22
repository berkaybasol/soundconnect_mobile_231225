part of 'table_group_list_screen.dart';

class _TableGroupListCard extends StatelessWidget {
  final TableGroup group;
  final VoidCallback onApply;
  final VoidCallback onOpenDetail;
  final bool joining;
  final String timeText;
  final String dayText;

  _TableGroupListCard({
    required this.group,
    required this.onApply,
    required this.onOpenDetail,
    required this.joining,
    required this.timeText,
    required this.dayText,
  });

  @override
  Widget build(BuildContext context) {
    final venue = group.venueName?.trim().isNotEmpty == true
        ? group.venueName!.trim()
        : 'Mekan belirtilmedi';
    final username = _resolveUsername(group);
    final avatarUrl = _validUrlOrNull(group.ownerProfileImageUrl);
    final initials = _initialsFrom(username);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenDetail,
        child: Container(
          padding: EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppColors.brandGradient,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          initials,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GradientVenueText(text: venue),
                    SizedBox(height: 2),
                    Text(
                      username,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.groups_2_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '+${(group.acceptedCount - 1).clamp(0, 99)}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 2),
                        Text(
                          timeText,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            dayText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: joining ? null : onApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tableGroupApplyGreen,
                          foregroundColor: AppColors.white,
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(joining ? 'Gonderiliyor...' : 'Basvur'),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              _MiniAvatars(
                participants: group.participants,
                ownerId: group.ownerId,
                maxPersonCount: group.maxPersonCount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveUsername(TableGroup group) {
    final fromBackend = group.ownerUsername?.trim();
    if (fromBackend != null && fromBackend.isNotEmpty) return fromBackend;
    final owner = group.ownerId.trim();
    if (owner.isEmpty) return 'Kullanici';
    return owner.length <= 8 ? owner : owner.substring(0, 8);
  }

  String _initialsFrom(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final first = words.first;
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first.toUpperCase();
    }
    return (words.first[0] + words[1][0]).toUpperCase();
  }

  String? _validUrlOrNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    return text;
  }
}

class _GradientVenueText extends StatelessWidget {
  final String text;

  _GradientVenueText({required this.text});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.white,
          fontSize: 20,
          height: 1.05,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationThickness: 1.0,
        ),
      ),
    );
  }
}

class _MiniAvatars extends StatelessWidget {
  final List<TableGroupParticipant> participants;
  final String ownerId;
  final int maxPersonCount;

  _MiniAvatars({
    required this.participants,
    required this.ownerId,
    required this.maxPersonCount,
  });

  @override
  Widget build(BuildContext context) {
    final acceptedGuests =
        participants
            .where(
              (p) =>
                  p.status == TableGroupParticipantStatus.accepted &&
                  p.userId != ownerId,
            )
            .toList()
          ..sort((a, b) {
            final at = a.joinedAt?.millisecondsSinceEpoch ?? 0;
            final bt = b.joinedAt?.millisecondsSinceEpoch ?? 0;
            return at.compareTo(bt);
          });

    final slotCount = (maxPersonCount - 1).clamp(0, 5);
    final shown = acceptedGuests.take(slotCount).toList();

    return SizedBox(
      width: 74,
      height: 30,
      child: Stack(
        children: [
          for (int i = 0; i < slotCount; i++)
            Positioned(
              left: i * 12,
              top: 2,
              child: i < shown.length
                  ? _FilledParticipantAvatar(participant: shown[i])
                  : _EmptyParticipantSlot(),
            ),
        ],
      ),
    );
  }
}

class _FilledParticipantAvatar extends StatelessWidget {
  final TableGroupParticipant participant;

  _FilledParticipantAvatar({required this.participant});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _validUrlOrNull(participant.profilePictureUrl);
    final initials = _initialsFrom(
      participant.username?.trim().isNotEmpty == true
          ? participant.username!.trim()
          : participant.userId,
    );
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainer,
          width: 1.4,
        ),
      ),
      child: CircleAvatar(
        radius: 13,
        backgroundColor: Theme.of(context).dividerColor,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
            ? Text(
                initials,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }

  String? _validUrlOrNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;
    return text;
  }

  String _initialsFrom(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final one = parts.first;
      return one.length >= 2
          ? one.substring(0, 2).toUpperCase()
          : one.toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

class _EmptyParticipantSlot extends StatelessWidget {
  _EmptyParticipantSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.2),
      ),
      child: Icon(
        Icons.add_rounded,
        size: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CreateTableFab extends StatefulWidget {
  final Future<void> Function() onTap;
  final ValueChanged<Offset> onDragDelta;

  _CreateTableFab({required this.onTap, required this.onDragDelta});

  @override
  State<_CreateTableFab> createState() => _CreateTableFabState();
}

class _CreateTableFabState extends State<_CreateTableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1150),
    );
    _scale = Tween<double>(
      begin: 0.98,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: (details) => widget.onDragDelta(details.delta),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pureBlack.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'Masa olusturmak\nicin buraya tiklayin',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandGradient.last.withValues(alpha: 0.42),
                    blurRadius: 16,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(
                Icons.groups_2_rounded,
                color: AppColors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
