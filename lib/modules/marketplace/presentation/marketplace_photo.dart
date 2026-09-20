import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/di/service_locator.dart';
import '../../../shared/images/private_media_image_cache.dart';
import '../../profile/domain/entities/media_access.dart';
import '../../profile/domain/media_gallery_repository.dart';
import '../domain/marketplace_models.dart';

/// A private photo always needs a fresh access grant before its session-bound
/// bytes can be reused. Neither signed URLs nor photo bytes reach a disk cache.
class MarketplacePhoto extends StatefulWidget {
  const MarketplacePhoto({
    required this.assetId,
    this.fit = BoxFit.cover,
    this.repository,
    this.sessions,
    this.cache,
    this.moderatorMode = false,
    this.preferOriginal = false,
    super.key,
  });
  final String assetId;
  final BoxFit fit;
  final MediaGalleryRepository? repository;
  final AuthSessionManager? sessions;
  final PrivateMediaImageCache? cache;
  final bool moderatorMode;
  final bool preferOriginal;

  @override
  State<MarketplacePhoto> createState() => _MarketplacePhotoState();
}

class _MarketplacePhotoState extends State<MarketplacePhoto>
    with WidgetsBindingObserver {
  late final _sessions =
      widget.sessions ?? serviceLocator<AuthSessionManager>();
  late final AuthSession _entry;
  final _decodedProviders = <ImageProvider<Object>>{};
  MediaAccess? _access;
  Uint8List? _bytes;
  DateTime? _expiresAt;
  Timer? _expiry;
  int _epoch = 0;
  bool _revoked = false, _foreground = true, _failed = false;

  PrivateMediaImageCache? get _cache =>
      widget.cache ??
      (serviceLocator.isRegistered<PrivateMediaImageCache>()
          ? serviceLocator<PrivateMediaImageCache>()
          : null);

  String get _accessScope =>
      widget.moderatorMode ? 'marketplace-moderator' : 'marketplace';

  bool get _allowed => widget.moderatorMode
      ? _entry.isAuthenticated &&
            _entry.isActive &&
            !_entry.requiresListenerProfileChoice &&
            !_entry.roles.any(
              (role) =>
                  role.trim().toUpperCase().replaceFirst('ROLE_', '') ==
                  'LISTENER',
            ) &&
            _entry.permissions.contains('MANAGE_MARKETPLACE_REPORTS')
      : canUseMarketplace(_entry);

  bool get _canLoad =>
      mounted &&
      !_revoked &&
      _foreground &&
      identical(_entry, _sessions.session) &&
      (_entry.expiresAt?.isAfter(DateTime.now()) ?? false) &&
      _allowed;

  @override
  void initState() {
    super.initState();
    _entry = _sessions.session;
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _sessions.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant MarketplacePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.sessions, oldWidget.sessions)) {
      _revoked = true;
      _invalidate();
      return;
    }
    if (widget.assetId != oldWidget.assetId ||
        widget.preferOriginal != oldWidget.preferOriginal ||
        widget.moderatorMode != oldWidget.moderatorMode ||
        !identical(widget.repository, oldWidget.repository) ||
        !identical(widget.cache, oldWidget.cache)) {
      _invalidate();
      unawaited(_load());
    }
  }

  void _clearPixels() {
    _access = null;
    _bytes = null;
    _expiresAt = null;
    // Flutter keeps decoded images separately from our bounded encoded cache.
    // Evict the exact resized keys as soon as this view loses its access grant.
    for (final provider in _decodedProviders) {
      unawaited(provider.evict());
    }
    _decodedProviders.clear();
  }

  void _invalidate() {
    _epoch++;
    _expiry?.cancel();
    _expiry = null;
    _clearPixels();
  }

  void _sessionChanged() {
    if (!identical(_entry, _sessions.session)) {
      _revoked = true;
      _invalidate();
      if (mounted) setState(() {});
    }
  }

  Future<void> _load() async {
    if (!_canLoad) return;
    _invalidate();
    final epoch = _epoch;
    final assetId = widget.assetId;
    final scope = _accessScope;
    setState(() => _failed = false);
    try {
      final result =
          await (widget.repository ?? serviceLocator<MediaGalleryRepository>())
              .getAccess(assetId);
      if (!_canLoad || epoch != _epoch) return;
      final access = result.data;
      if (!result.isSuccess || access == null || access.assetId != assetId) {
        _cache?.evict(session: _entry, assetId: assetId, accessScope: scope);
        setState(() => _failed = true);
        return;
      }
      final now = DateTime.now().toUtc();
      final thumbnail =
          !widget.preferOriginal &&
          (access.thumbnailAccessUrl?.trim().isNotEmpty ?? false) &&
          (access.thumbnailExpiresAt?.isAfter(now) ?? false);
      final grantExpiresAt = thumbnail
          ? access.thumbnailExpiresAt!
          : access.expiresAt;
      final sessionExpiry = _entry.expiresAt!;
      final sessionDeadline = !sessionExpiry.isAfter(grantExpiresAt);
      final expiresAt = sessionDeadline ? sessionExpiry : grantExpiresAt;
      if (!expiresAt.isAfter(now)) {
        _cache?.evict(session: _entry, assetId: assetId, accessScope: scope);
        setState(() => _failed = true);
        return;
      }
      final cache = _cache;
      if (cache == null) {
        setState(() => _failed = true);
        return;
      }
      _access = access;
      _expiresAt = expiresAt;
      _expiry = Timer(expiresAt.difference(now), () {
        if (!mounted || epoch != _epoch || _revoked) return;
        setState(() {
          if (sessionDeadline) _revoked = true;
          _invalidate();
        });
        unawaited(_load());
      });
      final bytes = await cache.getOrLoad(
        session: _entry,
        assetId: assetId,
        variant: thumbnail ? 'thumbnail' : 'original',
        accessScope: scope,
        authorizedUrl: thumbnail
            ? access.thumbnailAccessUrl!
            : access.accessUrl,
        expiresAt: expiresAt,
      );
      if (!_canLoad || epoch != _epoch) return;
      if (bytes.isEmpty || !expiresAt.isAfter(DateTime.now().toUtc())) {
        setState(() {
          _invalidate();
          _failed = true;
        });
        return;
      }
      setState(() => _bytes = bytes);
    } catch (_) {
      if (!_canLoad || epoch != _epoch) return;
      _invalidate();
      _cache?.evict(session: _entry, assetId: assetId, accessScope: scope);
      setState(() => _failed = true);
    }
  }

  void _retryDecodedImage() {
    if (!_canLoad) return;
    _cache?.evict(
      session: _entry,
      assetId: widget.assetId,
      accessScope: _accessScope,
    );
    unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _invalidate();
    if (mounted) setState(() {});
    if (_foreground) unawaited(_load());
  }

  @override
  void dispose() {
    _invalidate();
    _sessions.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (_canLoad &&
        _access != null &&
        bytes != null &&
        (_expiresAt?.isAfter(DateTime.now().toUtc()) ?? false)) {
      return LayoutBuilder(
        builder: (context, bounds) {
          final width = bounds.maxWidth.isFinite
              ? (bounds.maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(1, 1600)
              : 1600;
          final height = bounds.maxHeight.isFinite
              ? (bounds.maxHeight * MediaQuery.devicePixelRatioOf(context))
                    .round()
                    .clamp(1, 1600)
              : 1600;
          final provider = ResizeImage(
            MemoryImage(bytes),
            // Cover crops after decoding: fitting to the visible rectangle
            // first would shrink its cropped axis and then upscale it again.
            // Preserve the thumbnail's pixels (normally capped at 960 by the
            // server), with a 1600 ceiling for original/legacy fallback bytes.
            width: widget.fit == BoxFit.cover ? 1600 : width,
            height: widget.fit == BoxFit.cover ? 1600 : height,
            policy: ResizeImagePolicy.fit,
          );
          _decodedProviders.add(provider);
          return Image(
            image: provider,
            fit: widget.fit,
            gaplessPlayback: false,
            errorBuilder: (_, _, _) => Center(
              child: IconButton(
                onPressed: _retryDecodedImage,
                tooltip: 'Fotoğrafı yeniden yükle',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          );
        },
      );
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: !_canLoad
            ? const Icon(Icons.lock_outline_rounded)
            : _failed
            ? IconButton(
                onPressed: _load,
                tooltip: 'Fotoğrafı yeniden yükle',
                icon: const Icon(Icons.refresh_rounded),
              )
            : const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ),
    );
  }
}
