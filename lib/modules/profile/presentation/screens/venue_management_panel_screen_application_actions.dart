part of 'venue_management_panel_screen.dart';

extension _VenueApplicationsSheetStateActions on _VenueApplicationsSheetState {
  Future<void> _load({bool append = false}) async {
    if (!mounted || _accessRevoked) return;
    if (!_session.isCurrent) {
      _onSessionChanged();
      return;
    }
    if (append && (_loading || _loadingMore || _actionLoading || !_hasMore)) {
      return;
    }
    final generation = ++_loadGeneration;
    final page = append ? _nextPage : 0;
    _updateState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
        _error = null;
      }
      _pageError = null;
    });
    try {
      final result = await _artistVenueRepository.listApplicationPage(
        target: ArtistVenueApplicationTarget.venue,
        targetId: widget.venueId,
        incoming: !_showOutgoing,
        connectionsOnly: _showConnections,
        page: page,
        expectedSessionKey: _session.userId,
      );
      if (!mounted || !_session.isCurrent || generation != _loadGeneration) {
        return;
      }
      if (!result.isSuccess || result.data == null) {
        if (artistVenueAccessLost(result.error)) {
          _revokeAccess(
            result.error?.message ?? 'Bu isteklere erişim iznin kalmadı.',
          );
          return;
        }
        throw result.error?.message ?? 'İstekler getirilemedi.';
      }
      final response = result.data!;
      final overlaps =
          append &&
          response.items.any(
            (item) => _items.any((loaded) => loaded.id == item.id),
          );
      if (append && (response.totalElements != _totalElements || overlaps)) {
        await _load();
        return;
      }
      final unique = {
        if (append)
          for (final item in _items) item.id: item,
        for (final item in response.items) item.id: item,
      };
      _updateState(() {
        _items = unique.values.toList(growable: false);
        _totalElements = response.totalElements;
        _nextPage = response.page + 1;
        _hasMore = !response.last;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || !_session.isCurrent || generation != _loadGeneration) {
        return;
      }
      _updateState(() {
        _loading = false;
        _loadingMore = false;
        if (append) {
          _pageError = 'İstekler getirilemedi: $error';
        } else {
          _items = [];
          _hasMore = false;
          _error = 'İstekler getirilemedi: $error';
        }
      });
    }
  }

  bool _isValidImageUrl(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  Future<void> _runAction({
    required String requestId,
    required String methodLabel,
    required Future<Result<void>> Function() action,
  }) async {
    if (!mounted ||
        !_session.isCurrent ||
        _accessRevoked ||
        _actionLoading ||
        _loading ||
        _loadingMore) {
      return;
    }
    if (!_items.any((item) => item.id == requestId)) return;
    _loadGeneration++;
    _updateState(() => _actionLoading = true);
    try {
      final result = await action();
      if (!mounted || !_session.isCurrent) return;
      if (!result.isSuccess) {
        if (artistVenueAccessLost(result.error)) {
          _revokeAccess(
            result.error?.message ?? 'Bu isteklere erişim iznin kalmadı.',
          );
        } else if (artistVenueDecisionChanged(result.error)) {
          await _load();
        }
        throw result.error?.message ?? 'İşlem başarısız.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: Text(methodLabel),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted || !_session.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text('İşlem başarısız: $e'),
        ),
      );
    } finally {
      if (mounted && _session.isCurrent) {
        _updateState(() => _actionLoading = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACCEPTED':
        return Color(0xFF4CD47A);
      case 'REJECTED':
        return Theme.of(context).colorScheme.onSurfaceVariant;
      default:
        return Color(0xFFE7B65A);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACCEPTED':
        return 'Onaylandı';
      case 'REJECTED':
        return 'Reddedildi';
      default:
        return 'Beklemede';
    }
  }
}
