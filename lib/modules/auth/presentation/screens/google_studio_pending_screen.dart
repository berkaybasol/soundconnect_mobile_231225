import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/error/result.dart';
import '../../data/google_auth_repository.dart';
import '../../domain/entities/login_result.dart';
import '../../domain/entities/user_status.dart';
import 'venue_pending_screen.dart';

class GoogleStudioPendingScreen extends StatefulWidget {
  const GoogleStudioPendingScreen({
    super.key,
    required this.idToken,
    required this.application,
    required this.repository,
    required this.revision,
  });

  final String idToken;
  final LoginResult application;
  final GoogleAuthRepository repository;
  final int revision;

  @override
  State<GoogleStudioPendingScreen> createState() =>
      _GoogleStudioPendingScreenState();
}

class _GoogleStudioPendingScreenState extends State<GoogleStudioPendingScreen> {
  late String _idToken = widget.idToken;
  String? _notice;
  bool _checking = false;
  bool get _current => mounted && ModalRoute.of(context)?.isCurrent == true;

  // Compare accounts before sending a renewed proof. The backend verifies both
  // identity tokens; no authorization is derived from the local subject.
  static String? _subject(String token) {
    try {
      final payload = token.split('.');
      if (payload.length != 3) return null;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload[1]))),
      );
      return claims is Map && claims['sub'] is String
          ? claims['sub'] as String
          : null;
    } on FormatException {
      return null;
    }
  }

  Future<LoginResult?> _readStatus() async {
    try {
      return await widget.repository.signIn(_idToken, widget.revision);
    } catch (e) {
      if (!const {'1101', '401'}.contains(googleAuthError(e).code)) rethrow;
    }
    if (!_current) return null;
    final renewed = await widget.repository.chooseAccount();
    if (!_current || renewed == null) return null;
    final sub = _subject(_idToken);
    if (sub == null || sub.isEmpty || _subject(renewed) != sub) {
      setState(
        () => _notice = 'Başvurduğun Google hesabını seçerek tekrar dene.',
      );
      return null;
    }
    _idToken = renewed;
    return widget.repository.signIn(renewed, widget.revision);
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _notice = null;
    });
    try {
      final result = await _readStatus();
      if (!_current || result == null) return;
      if (result.userId != widget.application.userId) {
        setState(() => _notice = 'Başvuru sahibi doğrulanamadı.');
      } else if (result.status == UserStatus.pendingStudioRequest &&
          result.applicationId == widget.application.applicationId) {
        setState(() => _notice = 'Başvurunun incelemesi sürüyor.');
      } else if (result.status == UserStatus.active &&
          result.token.isNotEmpty &&
          result.roles.contains('ROLE_STUDIO') &&
          result.sessionScope == null) {
        Navigator.pop(context, Result<LoginResult>.success(result));
      } else {
        setState(() => _notice = 'Başvuru durumu doğrulanamadı. Tekrar dene.');
      }
    } catch (e) {
      if (!_current) return;
      final error = googleAuthError(e);
      if (error.code == 'auth_studio_application_rejected') {
        Navigator.pop(context, Result<LoginResult>.failure(error));
      } else {
        setState(() => _notice = error.message);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => VenuePendingScreen(
    membershipType: PendingMembershipType.studio,
    onReturnToLogin: () => Navigator.pop(context),
    statusAction: Column(
      children: [
        if (_notice != null)
          Semantics(
            liveRegion: true,
            child: Text(_notice!, textAlign: TextAlign.center),
          ),
        OutlinedButton(
          onPressed: _checking ? null : _check,
          child: Text(
            _checking ? 'Kontrol ediliyor…' : 'Başvuru durumunu kontrol et',
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
