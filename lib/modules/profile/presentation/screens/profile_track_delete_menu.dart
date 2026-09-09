import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../data/profile_track_deletion_repository.dart';

class ProfileTrackDeleteMenu extends StatefulWidget {
  final String ownerType;
  final String ownerId;
  final String trackId;
  final ProfileTrackDeletionRepository? repository;
  final Future<void> Function() onDeleted;
  const ProfileTrackDeleteMenu({
    super.key,
    required this.ownerType,
    required this.ownerId,
    required this.trackId,
    this.repository,
    required this.onDeleted,
  });
  @override
  State<ProfileTrackDeleteMenu> createState() => _ProfileTrackDeleteMenuState();
}

class _ProfileTrackDeleteMenuState extends State<ProfileTrackDeleteMenu> {
  bool _busy = false;
  bool _confirming = false;
  int _generation = 0;
  DialogRoute<bool>? _confirmation;

  @override
  void didUpdateWidget(covariant ProfileTrackDeleteMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerType != widget.ownerType ||
        oldWidget.ownerId != widget.ownerId ||
        oldWidget.trackId != widget.trackId ||
        oldWidget.repository != widget.repository) {
      ++_generation;
      _busy = false;
      _confirming = false;
      _dismissConfirmation();
    }
  }

  @override
  void dispose() {
    ++_generation;
    _dismissConfirmation();
    super.dispose();
  }

  void _dismissConfirmation() {
    final dialog = _confirmation;
    _confirmation = null;
    if (dialog == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _delete() async {
    if (!mounted ||
        _busy ||
        _confirming ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final target = widget;
    final generation = _generation;
    final repository =
        target.repository ??
        ProfileTrackDeletionRepository(
          serviceLocator<ApiClient>(),
          serviceLocator<AuthSessionManager>(),
        );
    final session = repository.sessions.session;
    bool current() =>
        mounted &&
        generation == _generation &&
        identical(session, repository.sessions.session);
    setState(() => _confirming = true);
    final dialog = DialogRoute<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ses silinsin mi?'),
        content: const Text(
          'Bu ses ve ona ait beğeni ve yorumlar kaldırılacak. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    _confirmation = dialog;
    try {
      final confirmed = await Navigator.of(context).push(dialog);
      if (identical(_confirmation, dialog)) _confirmation = null;
      if (!mounted ||
          !current() ||
          confirmed != true ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      setState(() {
        _confirming = false;
        _busy = true;
      });
      final result = await repository.delete(
        ownerType: target.ownerType,
        ownerId: target.ownerId,
        trackId: target.trackId,
      );
      if (!mounted || !current()) {
        return;
      }
      if (!result.isSuccess) {
        if (ModalRoute.of(context)?.isCurrent != true) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error?.message ?? 'Ses silinemedi.')),
        );
        return;
      }
      try {
        await target.onDeleted();
      } catch (_) {
        if (!mounted ||
            !current() ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ses silindi ancak liste yenilenemedi. Profili yeniden aç.',
            ),
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _busy
      ? const SizedBox(
          width: 48,
          height: 48,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      : SizedBox(
          width: 48,
          height: 48,
          child: PopupMenuButton<String>(
            enabled: !_confirming,
            tooltip: 'Ses seçenekleri',
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.more_vert,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onSelected: (_) => _delete(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Sil')),
            ],
          ),
        );
}
