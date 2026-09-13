import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../profile/domain/entities/media_access.dart';
import '../../../profile/domain/media_gallery_repository.dart';
import '../../domain/entities/announcement.dart';

/// Resolves expiring capabilities live; neither URLs nor private bytes enter
/// the public disk image cache. Revocation clears pixels immediately.
class AnnouncementMediaView extends StatefulWidget {
  const AnnouncementMediaView({
    super.key,
    required this.media,
    this.onPlay,
    this.repository,
    this.sessions,
  });
  final AnnouncementMedia media;
  final VoidCallback? onPlay;
  final MediaGalleryRepository? repository;
  final AuthSessionManager? sessions;
  @override
  State<AnnouncementMediaView> createState() => _AnnouncementMediaViewState();
}

class _AnnouncementMediaViewState extends State<AnnouncementMediaView>
    with WidgetsBindingObserver {
  late final _sessions =
      widget.sessions ?? serviceLocator<AuthSessionManager>();
  late final AuthSession _identity;
  MediaAccess? _access;
  String? _error;
  Timer? _expiry;
  int _epoch = 0;
  bool _revoked = false;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    _identity = _sessions.session;
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _sessions.addListener(_sessionChanged);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant AnnouncementMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.assetId != widget.media.assetId ||
        oldWidget.media.status != widget.media.status) {
      _access = null;
      unawaited(_load());
    }
  }

  void _sessionChanged() {
    if (!identical(_identity, _sessions.session)) {
      _revoked = true;
      _epoch++;
      _expiry?.cancel();
      if (mounted) {
        setState(() {
          _access = null;
          _error = 'Medya erişimi sona erdi.';
        });
      }
    }
  }

  Future<void> _load() async {
    if (_revoked || !_foreground || !mounted || widget.media.status != 'READY') {
      return;
    }
    final epoch = ++_epoch;
    _expiry?.cancel();
    final result =
        await (widget.repository ?? serviceLocator<MediaGalleryRepository>())
            .getAccess(widget.media.assetId);
    if (!mounted || _revoked || epoch != _epoch) return;
    setState(() {
      _access = result.data;
      _error = result.error?.message;
    });
    final access = _access;
    if (access == null) return;
    final expires = widget.media.isVideo
        ? (access.thumbnailExpiresAt ?? access.expiresAt)
        : access.expiresAt;
    final delay = expires.difference(DateTime.now().toUtc());
    _expiry = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (!mounted) return;
      setState(() => _access = null);
      unawaited(_load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && !_revoked) {
      unawaited(_load());
    } else {
      _epoch++;
      _expiry?.cancel();
      if (mounted) setState(() => _access = null);
    }
  }

  @override
  void dispose() {
    _epoch++;
    _expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _sessions.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final access = _access;
    final url = media.isVideo ? access?.thumbnailAccessUrl : access?.accessUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: media.aspectRatio.clamp(.65, 2.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              LayoutBuilder(
                builder: (context, bounds) => AppCachedNetworkImage(
                  imageUrl: url,
                  persistentCache: false,
                  cacheWidth:
                      (bounds.maxWidth * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                ),
              )
            else
              ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(
                  child: _error != null
                      ? TextButton(
                          onPressed: _revoked ? null : _load,
                          child: Text(_error!),
                        )
                      : media.status != 'READY'
                      ? Text(
                          media.status == 'FAILED'
                              ? 'Medya hazırlanamadı'
                              : 'Medya hazırlanıyor…',
                        )
                      : media.isVideo && access != null
                      ? const Icon(Icons.videocam_outlined, size: 48)
                      : const CircularProgressIndicator(),
                ),
              ),
            if (media.isVideo &&
                widget.onPlay != null &&
                !_revoked &&
                media.status == 'READY')
              Center(
                child: IconButton.filled(
                  onPressed: widget.onPlay,
                  iconSize: 42,
                  tooltip: 'Duyuru videosunu oynat',
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
