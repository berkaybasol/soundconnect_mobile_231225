import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/entities/overthinking_post.dart';
import '../../domain/overthinking_profile_share_repository.dart';
import '../overthinking_profile_draft.dart';
import 'overthinking_design.dart';

/// Mainstage also contains musicians; this action belongs to listeners only.
class OverthinkingProfileShareButton extends StatefulWidget {
  const OverthinkingProfileShareButton({
    super.key,
    required this.post,
    this.enabled = true,
    this.sessions,
    this.repository,
  });

  final OverthinkingPost post;
  final bool enabled;
  final AuthSessionManager? sessions;
  final OverthinkingProfileShareRepository? repository;

  @override
  State<OverthinkingProfileShareButton> createState() =>
      _OverthinkingProfileShareButtonState();
}

class _OverthinkingProfileShareButtonState
    extends State<OverthinkingProfileShareButton> {
  late final AuthSessionManager? _sessions;
  late final AuthSession? _expected;
  late final OverthinkingProfileShareRepository? _repository;
  bool _opening = false;

  bool get _allowed =>
      _repository != null &&
      _sessions != null &&
      identical(_sessions.session, _expected) &&
      canShareOverthinkingOnProfile(_expected);

  @override
  void initState() {
    super.initState();
    _sessions = widget.sessions ?? _registered<AuthSessionManager>();
    _repository =
        widget.repository ?? _registered<OverthinkingProfileShareRepository>();
    _expected = _sessions?.session;
    _sessions?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sessions?.removeListener(_changed);
    super.dispose();
  }

  Future<void> _open() async {
    if (!_allowed || !widget.enabled || _opening) return;
    setState(() => _opening = true);
    try {
      await openOverthinkingProfileDraft(
        context,
        postId: widget.post.id,
        expectedSession: _expected!,
        sessions: _sessions,
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const SizedBox.shrink();
    return TextButton.icon(
      key: ValueKey('overthinking-profile-share-${widget.post.id}'),
      onPressed: widget.enabled && !_opening ? _open : null,
      style: TextButton.styleFrom(
        foregroundColor: TableGroupOverviewStyle.bodyMuted,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      icon: const Icon(Icons.ios_share_rounded, size: 19),
      label: const Text('Paylaş'),
    );
  }
}

T? _registered<T extends Object>() =>
    serviceLocator.isRegistered<T>() ? serviceLocator<T>() : null;
