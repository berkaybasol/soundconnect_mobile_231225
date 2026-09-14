import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../domain/engagement_repository.dart';
import '../../domain/entities/comment_user_summary.dart';
import '../../domain/entities/like_user_page.dart';

/// The complete target's likes, independent of the followed-actors preview in
/// a feed reason. Pages and navigation remain bound to the opening session.
class LikeUsersSheet extends StatefulWidget {
  const LikeUsersSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.repository,
    required this.sessions,
    this.isCurrent,
    this.resolver,
  });

  final String targetType;
  final String targetId;
  final EngagementRepository repository;
  final AuthSessionManager sessions;
  final bool Function()? isCurrent;
  final DmUserProfileResolver? resolver;

  @override
  State<LikeUsersSheet> createState() => _LikeUsersSheetState();
}

class _LikeUsersSheetState extends State<LikeUsersSheet> {
  final _scroll = ScrollController();
  final _users = <CommentUserSummary>[];
  final _userIds = <String>{};
  final _cursors = <String>{};
  late AuthSession _session;
  int _generation = 0;
  String? _nextCursor;
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;
  bool _invalidated = false;
  bool _openingProfile = false;

  bool get _current =>
      mounted &&
      !_invalidated &&
      identical(widget.sessions.session, _session) &&
      _session.isAuthenticated &&
      _session.isActive &&
      !_session.requiresListenerProfileChoice &&
      (widget.isCurrent?.call() ?? true);

  @override
  void initState() {
    super.initState();
    _session = widget.sessions.session;
    widget.sessions.addListener(_sessionChanged);
    _scroll.addListener(_nearEnd);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant LikeUsersSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sessions, widget.sessions)) {
      oldWidget.sessions.removeListener(_sessionChanged);
      widget.sessions.addListener(_sessionChanged);
      _invalidate();
      return;
    }
    if (!_current) {
      _invalidate();
    } else if (oldWidget.targetType != widget.targetType ||
        oldWidget.targetId != widget.targetId ||
        !identical(oldWidget.repository, widget.repository)) {
      _generation++;
      _users.clear();
      _userIds.clear();
      _cursors.clear();
      _nextCursor = null;
      _loading = false;
      _hasMore = true;
      _failed = false;
      unawaited(_load());
    }
  }

  void _sessionChanged() {
    if (!mounted || identical(widget.sessions.session, _session)) return;
    setState(_invalidate);
  }

  void _invalidate() {
    _generation++;
    _invalidated = true;
    _loading = false;
    _users.clear();
    _userIds.clear();
    _cursors.clear();
    _nextCursor = null;
  }

  void _nearEnd() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 180 && !_failed) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (!_current || _loading || !_hasMore) return;
    final generation = _generation;
    final cursor = _nextCursor;
    setState(() {
      _loading = true;
      _failed = false;
    });
    Result<LikeUserPage>? result;
    try {
      result = await widget.repository.listLikeUsers(
        targetType: widget.targetType,
        targetId: widget.targetId,
        cursor: cursor,
      );
    } catch (_) {
      // Transport exceptions use the same retry surface as Result failures.
    }
    if (!mounted || generation != _generation) return;
    if (!_current) {
      setState(_invalidate);
      return;
    }
    final page = result?.data;
    setState(() {
      _loading = false;
      if (result?.isSuccess != true || page == null) {
        _failed = true;
        return;
      }
      for (final user in page.items) {
        final id = user.id.trim();
        if (id.isNotEmpty && _userIds.add(id)) _users.add(user);
      }
      if (cursor != null) _cursors.add(cursor);
      final next = page.nextCursor?.trim();
      // A broken/replayed cursor must never make scrolling issue requests
      // forever. Identity deduplication also handles likes moving between pages.
      _hasMore =
          page.hasMore &&
          next != null &&
          next.isNotEmpty &&
          !_cursors.contains(next);
      _nextCursor = _hasMore ? next : null;
    });
  }

  Future<void> _openUser(CommentUserSummary user) async {
    final route = ModalRoute.of(context);
    if (!_current ||
        _openingProfile ||
        route?.isCurrent != true ||
        user.id.trim().isEmpty) {
      return;
    }
    final generation = _generation;
    bool valid() => _current && generation == _generation;
    _openingProfile = true;
    try {
      final own = user.id.trim() == _session.userId?.trim();
      if (own) {
        final ownTypes = <DmProfileTargetType>[
          if (_session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']))
            DmProfileTargetType.listener,
          if (_session.hasAnyRole(const ['MUSICIAN', 'ROLE_MUSICIAN']))
            DmProfileTargetType.musician,
          if (_session.hasAnyRole(const ['VENUE', 'ROLE_VENUE']))
            DmProfileTargetType.venue,
          if (_session.hasAnyRole(const ['STUDIO', 'ROLE_STUDIO']))
            DmProfileTargetType.studio,
        ];
        if (ownTypes.length == 1) {
          await Navigator.of(
            context,
          ).pushNamed(ownerProfileRouteFor(ownTypes.single));
          return;
        }
      }
      final resolver =
          widget.resolver ?? serviceLocator<DmUserProfileResolver>();
      final resolved = await resolver.resolveByUserId(userId: user.id.trim());
      if (!mounted || !valid() || route?.isCurrent != true) return;
      final seen = <String>{};
      final targets = resolved
          .where((target) {
            return (target.isStudioRestricted || target.id.trim().isNotEmpty) &&
                seen.add('${target.type.name}:${target.id.trim()}');
          })
          .toList(growable: false);
      if (targets.isEmpty) {
        _profileError('Profil şu anda açılamıyor.');
        return;
      }
      final target = targets.length == 1
          ? targets.single
          : await _pickProfile(targets, user.username.trim(), valid);
      if (!mounted || !valid() || target == null || route?.isCurrent != true) {
        return;
      }
      final destination = dmProfileRouteFor(target);
      if (destination == null) return;
      await Navigator.of(context).pushNamed(
        own ? ownerProfileRouteFor(target.type) : destination.routeName,
        arguments: own ? null : destination.arguments,
      );
    } catch (_) {
      if (mounted && valid() && route?.isCurrent == true) {
        _profileError('Profil açılamadı. Yeniden deneyebilirsin.');
      }
    } finally {
      _openingProfile = false;
    }
  }

  Future<DmProfileTarget?> _pickProfile(
    List<DmProfileTarget> targets,
    String username,
    bool Function() valid,
  ) => showModalBottomSheet<DmProfileTarget>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: widget.sessions,
      builder: (_, _) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
          ),
          child: !valid()
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Oturum değişti. Bu pencereyi kapatabilirsin.'),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Profili seç',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final target in targets)
                      ListTile(
                        title: Text(
                          target.type == DmProfileTargetType.musician
                              ? (username.isEmpty ? 'Müzisyen' : username)
                              : target.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(target.type.displayLabel),
                        trailing: target.isGhostListener
                            ? const GhostProfileBadge(showLabel: false)
                            : null,
                        onTap: () {
                          if (valid()) Navigator.of(sheetContext).pop(target);
                        },
                      ),
                  ],
                ),
        ),
      ),
    ),
  );

  void _profileError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(context, tone: AppSnackBarTone.info, content: Text(message)),
    );
  }

  @override
  void dispose() {
    _generation++;
    widget.sessions.removeListener(_sessionChanged);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Beğenenler',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (!_current) {
      return _message('Beğenileri görmek için akışı yeniden açabilirsin.');
    }
    if (_users.isEmpty) {
      if (_loading) {
        return const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Beğenenler yükleniyor',
          ),
        );
      }
      if (_failed) {
        return _message('Beğenenler yüklenemedi.', retry: true);
      }
      if (!_hasMore) return _message('Henüz beğeni yok.');
    }
    return ListView.builder(
      key: const Key('like-users-list'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _users.length + 1,
      itemBuilder: (context, index) {
        if (index == _users.length) {
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Diğer beğenenler yükleniyor',
                ),
              ),
            );
          }
          if (_failed) {
            return _message('Diğer beğeniler yüklenemedi.', retry: true);
          }
          if (!_hasMore) return const SizedBox.shrink();
          return Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('Daha fazla göster'),
            ),
          );
        }
        final user = _users[index];
        return _LikeUserRow(user: user, onTap: () => _openUser(user));
      },
    );
  }

  Widget _message(String text, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (retry) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Yeniden dene')),
          ],
        ],
      ),
    ),
  );
}

class _LikeUserRow extends StatelessWidget {
  const _LikeUserRow({required this.user, required this.onTap});
  final CommentUserSummary user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = user.username.trim();
    final url = user.avatarUrl?.trim() ?? '';
    final placeholder = Center(
      child: name.isEmpty
          ? const Icon(Icons.person_outline_rounded)
          : Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
    );
    return Semantics(
      button: true,
      onTap: onTap,
      label:
          '${name.isEmpty ? 'Kullanıcı' : name}${user.isGhost ? ', hayalet profil' : ''}, profili aç',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('like-user-${user.id.trim()}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox.square(
                      dimension: 44,
                      child: ColoredBox(
                        color: colors.surfaceContainerHigh,
                        child: url.isEmpty
                            ? placeholder
                            : AppCachedNetworkImage(
                                imageUrl: url,
                                width: 44,
                                height: 44,
                                cacheWidth: 132,
                                cacheHeight: 132,
                                fit: BoxFit.cover,
                                errorBuilder: (_) => placeholder,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Kullanıcı' : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (user.isGhost) ...[
                          const SizedBox(height: 5),
                          const GhostProfileBadge(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                    size: 22,
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
