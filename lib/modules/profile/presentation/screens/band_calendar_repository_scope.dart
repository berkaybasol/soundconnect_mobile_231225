import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/band_calendar_repository_factory.dart';
import '../../domain/musician_calendar_repository.dart';

/// Profile and founder settings share a live repository, then release it when
/// both leave the navigation stack.
class BandCalendarRepositoryScope extends StatefulWidget {
  const BandCalendarRepositoryScope({
    super.key,
    required this.bandId,
    required this.builder,
    this.factory,
  });

  final String bandId;
  final Widget Function(MusicianCalendarRepository repository) builder;
  final BandCalendarRepositoryFactory? factory;

  @override
  State<BandCalendarRepositoryScope> createState() =>
      _BandCalendarRepositoryScopeState();
}

class _BandCalendarRepositoryScopeState
    extends State<BandCalendarRepositoryScope> {
  BandCalendarRepositoryFactory? _factory;
  MusicianCalendarRepository? _repository;
  String? _bandId;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant BandCalendarRepositoryScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bandId.trim() != widget.bandId.trim() ||
        oldWidget.factory != widget.factory) {
      _release();
      _bind();
    }
  }

  void _bind() {
    final id = widget.bandId.trim();
    if (id.isEmpty) return;
    final factory =
        widget.factory ??
        (serviceLocator.isRegistered<BandCalendarRepositoryFactory>()
            ? serviceLocator<BandCalendarRepositoryFactory>()
            : null);
    if (factory == null) return;
    _factory = factory;
    _bandId = id;
    _repository = factory.acquire(id);
  }

  void _release() {
    final factory = _factory;
    final bandId = _bandId;
    _factory = null;
    _repository = null;
    _bandId = null;
    if (factory != null && bandId != null) {
      unawaited(factory.release(bandId));
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    return repository == null
        ? const SizedBox.shrink()
        : widget.builder(repository);
  }
}
