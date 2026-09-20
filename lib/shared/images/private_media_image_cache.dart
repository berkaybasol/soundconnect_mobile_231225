import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../core/auth/auth_session.dart';
import '../../core/auth/auth_session_manager.dart';
import '../../core/network/app_media_url.dart';

/// A deliberately opaque failure: signed storage URLs must not reach logs/UI.
class PrivateMediaImageUnavailable implements Exception {
  const PrivateMediaImageUnavailable();

  @override
  String toString() => 'Private media image unavailable';
}

typedef _ImageKey = ({
  String asset,
  String variant,
  String scope,
  String source,
});

/// Short-lived, memory-only storage for already authorized private images.
///
/// Callers MUST obtain fresh server authorization before every [getOrLoad],
/// including hits. This caches bytes, never permissions or signed URL results.
/// No authenticated API client is used for storage downloads. Owners of decoded
/// ImageProviders must evict those separately when their authorization ends.
class PrivateMediaImageCache with WidgetsBindingObserver {
  PrivateMediaImageCache({
    required AuthSessionManager sessions,
    Dio? dio,
    this.maxBytes = 24 * 1024 * 1024,
    this.maxEntries = 64,
    this.maxConcurrent = 4,
    this.maxPending = 64,
    // Matches the server IMAGE upload contract, including pre-existing assets.
    this.maxFileBytes = 20 * 1000 * 1000,
    this.downloadTimeout = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : assert(maxBytes > 0),
       assert(maxEntries > 0),
       assert(maxConcurrent > 0),
       assert(maxPending > 0),
       assert(maxFileBytes > 0),
       assert(downloadTimeout > Duration.zero),
       _sessions = sessions,
       _dio =
           dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10))),
       _ownsDio = dio == null,
       _clock = clock ?? DateTime.now {
    _session = sessions.session;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    sessions.addListener(_onSessionChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  final AuthSessionManager _sessions;
  final Dio _dio;
  final bool _ownsDio;
  final DateTime Function() _clock;
  final int maxBytes;
  final int maxEntries;
  final int maxConcurrent;
  final int maxPending;
  final int maxFileBytes;
  final Duration downloadTimeout;
  final _entries = <_ImageKey, _ImageEntry>{};
  final _jobs = <_ImageKey, _ImageDownload>{};
  final _queue = Queue<_ImageDownload>();
  late AuthSession _session;
  late bool _foreground;
  bool _disposed = false;
  int _bytes = 0;
  int _active = 0;
  int _epoch = 0;
  Timer? _expiryTimer;

  Future<Uint8List> getOrLoad({
    required AuthSession session,
    required String assetId,
    required String variant,
    required String accessScope,
    required String authorizedUrl,
    required DateTime expiresAt,
  }) async {
    final url = resolveAppMediaUrl(authorizedUrl);
    final uri = url == null ? null : Uri.tryParse(url);
    if (!_allowed(session, expiresAt) ||
        assetId.trim().isEmpty ||
        variant.trim().isEmpty ||
        accessScope.trim().isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty) {
      throw const PrivateMediaImageUnavailable();
    }
    final key = (
      asset: assetId,
      variant: variant,
      scope: accessScope,
      // The server's immutable object path survives signed URL renewal.
      source: uri.replace(query: '', fragment: '').toString(),
    );
    _prune();
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached.bytes;
    }
    final pending = _jobs[key];
    if (pending != null && _current(pending)) {
      final bytes = await pending.result.future;
      if (!_allowed(session, expiresAt)) {
        throw const PrivateMediaImageUnavailable();
      }
      return bytes;
    }
    if (pending != null) {
      // A freshly renewed grant must not join an expired queued/download job.
      _jobs.remove(key);
      _queue.remove(pending);
      pending.cancel();
    }
    if (_queue.length >= maxPending) {
      throw const PrivateMediaImageUnavailable();
    }
    final sessionExpiry = session.expiresAt!;
    final deadline = expiresAt.isBefore(sessionExpiry)
        ? expiresAt
        : sessionExpiry;
    final job = _ImageDownload(key, session, url!, deadline, _epoch);
    _jobs[key] = job;
    _queue.add(job);
    _pump();
    return job.result.future;
  }

  void evict({
    required AuthSession session,
    required String assetId,
    String? accessScope,
  }) {
    if (!identical(session, _session)) return;
    bool matches(_ImageKey key) =>
        key.asset == assetId &&
        (accessScope == null || key.scope == accessScope);
    for (final key in _entries.keys.where(matches).toList()) {
      _bytes -= _entries.remove(key)!.bytes.length;
    }
    for (final job in _jobs.values.where((job) => matches(job.key)).toList()) {
      _jobs.remove(job.key);
      _queue.remove(job);
      job.cancel();
    }
    _scheduleExpiry();
  }

  bool _allowed(AuthSession session, DateTime expiresAt) {
    final now = _clock();
    return !_disposed &&
        _foreground &&
        identical(session, _session) &&
        identical(session, _sessions.session) &&
        session.isAuthenticated &&
        session.isActive &&
        !session.requiresListenerProfileChoice &&
        session.userId?.isNotEmpty == true &&
        session.expiresAt?.isAfter(now) == true &&
        expiresAt.isAfter(now);
  }

  bool _current(_ImageDownload job) =>
      job.epoch == _epoch &&
      identical(_jobs[job.key], job) &&
      _allowed(job.session, job.expiresAt);

  void _pump() {
    while (!_disposed &&
        _foreground &&
        _active < maxConcurrent &&
        _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      if (!_current(job)) {
        if (identical(_jobs[job.key], job)) _jobs.remove(job.key);
        job.cancel();
        continue;
      }
      _active++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_ImageDownload job) async {
    try {
      final bytes = await _download(job).timeout(
        downloadTimeout,
        onTimeout: () {
          job.token.cancel();
          throw const PrivateMediaImageUnavailable();
        },
      );
      if (!_current(job)) throw const PrivateMediaImageUnavailable();
      if (bytes.length <= maxBytes) {
        _prune();
        while (_entries.isNotEmpty &&
            (_entries.length >= maxEntries ||
                _bytes + bytes.length > maxBytes)) {
          _bytes -= _entries.remove(_entries.keys.first)!.bytes.length;
        }
        _entries[job.key] = _ImageEntry(bytes, job.expiresAt);
        _bytes += bytes.length;
        _scheduleExpiry();
      }
      if (!job.result.isCompleted) job.result.complete(bytes);
    } catch (_) {
      job.cancel();
    } finally {
      if (identical(_jobs[job.key], job)) _jobs.remove(job.key);
      _active--;
      _pump();
    }
  }

  Future<Uint8List> _download(_ImageDownload job) async {
    final response = await _dio.get<ResponseBody>(
      job.url,
      cancelToken: job.token,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (status) => status == 200,
        headers: const {'Accept': 'image/*'},
      ),
    );
    final body = response.data;
    final size = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
    final mime = response.headers
        .value(Headers.contentTypeHeader)
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (body == null ||
        response.statusCode != 200 ||
        (size != null && size > maxFileBytes) ||
        (mime != null &&
            !mime.startsWith('image/') &&
            mime != 'application/octet-stream')) {
      throw const PrivateMediaImageUnavailable();
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in body.stream) {
      if (!_current(job) || builder.length + chunk.length > maxFileBytes) {
        throw const PrivateMediaImageUnavailable();
      }
      builder.add(chunk);
    }
    if (builder.isEmpty) throw const PrivateMediaImageUnavailable();
    return builder.takeBytes().asUnmodifiableView();
  }

  void _prune() {
    final now = _clock();
    for (final key
        in _entries.keys
            .where((key) => !_entries[key]!.expiresAt.isAfter(now))
            .toList()) {
      _bytes -= _entries.remove(key)!.bytes.length;
    }
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (_entries.isEmpty) return;
    final first = _entries.values
        .map((entry) => entry.expiresAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = first.difference(_clock());
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, _prune);
  }

  void _onSessionChanged() {
    if (identical(_session, _sessions.session)) return;
    _session = _sessions.session;
    _clear();
  }

  void _clear() {
    _epoch++;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _entries.clear();
    _bytes = 0;
    final jobs = _jobs.values.toList();
    _jobs.clear();
    _queue.clear();
    for (final job in jobs) {
      job.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _clear();
  }

  @override
  void didHaveMemoryPressure() => _clear();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clear();
    _sessions.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsDio) _dio.close(force: true);
  }
}

class _ImageEntry {
  const _ImageEntry(this.bytes, this.expiresAt);
  final Uint8List bytes;
  final DateTime expiresAt;
}

class _ImageDownload {
  _ImageDownload(this.key, this.session, this.url, this.expiresAt, this.epoch);
  final _ImageKey key;
  final AuthSession session;
  final String url;
  final DateTime expiresAt;
  final int epoch;
  final token = CancelToken();
  final result = Completer<Uint8List>();

  void cancel() {
    token.cancel();
    if (!result.isCompleted) {
      result.completeError(const PrivateMediaImageUnavailable());
    }
  }
}
