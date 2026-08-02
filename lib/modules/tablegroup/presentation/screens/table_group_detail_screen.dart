import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/token_store.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../dm/data/dm_auth_support.dart';
import '../../../dm/domain/dm_user_profile_resolver.dart';
import '../../../dm/domain/entities/dm_profile_target.dart';
import '../../../dm/presentation/dm_profile_navigation.dart';
import '../../data/table_group_chat_realtime_client.dart';
import '../../domain/entities/table_group.dart';
import '../../domain/entities/table_group_message.dart';
import '../../domain/entities/table_group_participant.dart';
import '../../domain/table_group_repository.dart';

class TableGroupDetailArgs {
  final String tableGroupId;
  final StageMode bottomBarStageMode;

  const TableGroupDetailArgs({
    required this.tableGroupId,
    this.bottomBarStageMode = StageMode.backstage,
  });
}

class TableGroupDetailScreen extends StatefulWidget {
  final TableGroupDetailArgs args;

  const TableGroupDetailScreen({super.key, required this.args});

  @override
  State<TableGroupDetailScreen> createState() => _TableGroupDetailScreenState();
}

class _TableGroupDetailScreenState extends State<TableGroupDetailScreen> {
  late final TableGroupRepository _repository;
  late final TokenStore _tokenStore;
  late final TableGroupChatRealtimeClient _realtimeClient;
  final TextEditingController _chatController = TextEditingController();

  StreamSubscription<TableGroupMessage>? _messageSubscription;
  bool _loading = true;
  bool _chatLoading = false;
  bool _sending = false;
  String? _error;
  String? _currentUserId;
  TableGroup? _group;
  List<TableGroupMessage> _messages = const [];
  bool _chatHasNext = false;
  int _chatPage = 0;
  final Set<String> _ownerActionInFlightIds = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = serviceLocator<TableGroupRepository>();
    _tokenStore = serviceLocator<TokenStore>();
    _realtimeClient = serviceLocator<TableGroupChatRealtimeClient>();
    _realtimeClient.retain();
    _messageSubscription = _realtimeClient.messageStream.listen(_onRealtimeMsg);
    _bootstrap();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _messageSubscription?.cancel();
    unawaited(_realtimeClient.release());
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _currentUserId = await resolveCurrentUserId(_tokenStore);
      await _loadDetail();
      await _loadMessages(reset: true);
      final token = await readAuthToken(_tokenStore);
      if (token != null) {
        try {
          await _realtimeClient.connect(
            tableGroupId: widget.args.tableGroupId,
            token: token,
          );
        } catch (_) {
          // Detail and message history remain usable without realtime.
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error ??= 'Masa detaylari yuklenemedi';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadDetail() async {
    final result = await _repository.getDetail(widget.args.tableGroupId);
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _error = result.error?.message ?? 'Masa detayi alinamadi';
      });
      return;
    }
    setState(() {
      _group = result.data;
    });
  }

  Future<void> _loadMessages({required bool reset}) async {
    if (_chatLoading) return;
    setState(() {
      _chatLoading = true;
    });
    final targetPage = reset ? 0 : _chatPage + 1;
    final result = await _repository.getChatMessages(
      tableGroupId: widget.args.tableGroupId,
      page: targetPage,
      size: 30,
    );
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      setState(() {
        _chatLoading = false;
      });
      return;
    }
    final incoming = result.data!;
    setState(() {
      _messages = reset ? incoming.items : [..._messages, ...incoming.items];
      _chatPage = targetPage;
      _chatHasNext = incoming.hasNext;
      _chatLoading = false;
    });
  }

  void _onRealtimeMsg(TableGroupMessage message) {
    if (message.tableGroupId != widget.args.tableGroupId) return;
    if (_messages.any((item) => item.messageId == message.messageId)) return;
    if (!mounted) return;
    setState(() {
      _messages = [..._messages, message];
    });
  }

  TableGroupParticipantStatus? get _myStatus {
    final userId = _currentUserId;
    if (userId == null || _group == null) return null;
    for (final p in _group!.participants) {
      if (p.userId == userId) return p.status;
    }
    return null;
  }

  bool get _isOwner =>
      _group != null &&
      _currentUserId != null &&
      _group!.ownerId == _currentUserId;

  bool get _isAccepted =>
      _isOwner || _myStatus == TableGroupParticipantStatus.accepted;

  Future<void> _sendMessage() async {
    final content = _chatController.text.trim();
    if (content.isEmpty) return;
    if (content.length > 1000) {
      _showSnack('Mesaj en fazla 1000 karakter olabilir');
      return;
    }
    setState(() {
      _sending = true;
    });
    final result = await _repository.sendChatMessage(
      tableGroupId: widget.args.tableGroupId,
      content: content,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
    });
    if (!result.isSuccess || result.data == null) {
      _showSnack(result.error?.message ?? 'Mesaj gonderilemedi');
      return;
    }
    _chatController.clear();
    if (_messages.any((item) => item.messageId == result.data!.messageId)) {
      return;
    }
    setState(() {
      _messages = [..._messages, result.data!];
    });
  }

  Future<void> _join() async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Masaya katil'),
        content: TextField(
          controller: controller,
          maxLength: 256,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Kisa bir not yazabilirsin',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Gonder'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await _repository.joinTableGroup(
      tableGroupId: widget.args.tableGroupId,
      note: controller.text.trim(),
    );
    _showSnack(
      result.isSuccess
          ? 'Basvuru gonderildi'
          : (result.error?.message ?? 'Islem basarisiz'),
    );
    if (result.isSuccess) {
      await _loadDetail();
      if (mounted) setState(() {});
    }
  }

  Future<void> _runOwnerAction({
    required String participantId,
    required Future<void> Function() fn,
  }) async {
    if (_ownerActionInFlightIds.contains(participantId)) return;
    setState(() {
      _ownerActionInFlightIds.add(participantId);
    });
    try {
      await fn();
      await _loadDetail();
    } finally {
      if (mounted) {
        setState(() {
          _ownerActionInFlightIds.remove(participantId);
        });
      }
    }
  }

  Future<void> _approve(String participantId) async {
    final result = await _repository.approveJoinRequest(
      tableGroupId: widget.args.tableGroupId,
      participantId: participantId,
    );
    _showSnack(
      result.isSuccess
          ? 'Onaylandi'
          : (result.error?.message ?? 'Islem basarisiz'),
    );
  }

  Future<void> _reject(String participantId) async {
    final result = await _repository.rejectJoinRequest(
      tableGroupId: widget.args.tableGroupId,
      participantId: participantId,
    );
    _showSnack(
      result.isSuccess
          ? 'Reddedildi'
          : (result.error?.message ?? 'Islem basarisiz'),
    );
  }

  Future<void> _leave() async {
    final result = await _repository.leaveTableGroup(
      tableGroupId: widget.args.tableGroupId,
    );
    _showSnack(
      result.isSuccess
          ? 'Masadan ayrildin'
          : (result.error?.message ?? 'Islem basarisiz'),
    );
  }

  Future<void> _cancelTable() async {
    final result = await _repository.cancelTableGroup(
      tableGroupId: widget.args.tableGroupId,
    );
    _showSnack(
      result.isSuccess
          ? 'Masa iptal edildi'
          : (result.error?.message ?? 'Islem basarisiz'),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final venueTitle = group?.venueName?.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (venueTitle != null && venueTitle.isNotEmpty)
              ? venueTitle
              : 'Masa Detayi',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _bootstrap,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            )
          : group == null
          ? const Center(child: Text('Masa bulunamadi'))
          : _isAccepted
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: _chatPanel(fullScreen: true),
            )
          : RefreshIndicator(
              onRefresh: _bootstrap,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (_showActionsCard) _actionsCard(),
                  const SizedBox(height: 12),
                  _chatAccessInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _actionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!_isOwner && _myStatus == null)
              FilledButton(onPressed: _join, child: const Text('Basvur')),
            if (!_isOwner && _myStatus == TableGroupParticipantStatus.pending)
              const Chip(label: Text('Basvuru beklemede')),
            if (!_isOwner && _isAccepted)
              OutlinedButton(onPressed: _leave, child: const Text('Ayril')),
          ],
        ),
      ),
    );
  }

  Widget _chatPanel({required bool fullScreen}) {
    final group = _group;
    final participants = group == null
        ? const <TableGroupParticipant>[]
        : group.participants.toList();

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!fullScreen)
            const Text('Sohbet', style: TextStyle(fontWeight: FontWeight.w700)),
          if (_isOwner || (!_isOwner && _isAccepted)) ...[
            if (!fullScreen) const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!_isOwner && _isAccepted)
                    SizedBox(
                      width: 120,
                      child: _brandOutlineButton(label: 'Ayril', onTap: _leave),
                    ),
                  if (_isOwner)
                    SizedBox(
                      width: 170,
                      child: _brandOutlineButton(
                        label: 'Oturumu Sonlandir',
                        onTap: _cancelTable,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (fullScreen)
            Expanded(child: _chatRoom(participants))
          else
            SizedBox(height: 440, child: _chatRoom(participants)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_chatHasNext)
                TextButton(
                  onPressed: _chatLoading
                      ? null
                      : () => _loadMessages(reset: false),
                  child: const Text('Daha fazla'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    hintText: 'Mesaj yaz',
                    counterText: '',
                  ),
                  enabled: _isAccepted,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 116,
                child: _brandOutlineButton(
                  label: _sending ? 'Gonderiliyor...' : 'Gonder',
                  onTap: (_sending || !_isAccepted) ? null : _sendMessage,
                  compact: true,
                ),
              ),
            ],
          ),
          if (!_isAccepted)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Sohbet icin accepted olman gerekiyor'),
            ),
        ],
      ),
    );

    if (fullScreen) return content;
    return Card(child: content);
  }

  Widget _chatRoom(List<TableGroupParticipant> participants) {
    final pendingRequests = _isOwner
        ? _pendingJoinRequests
        : const <TableGroupParticipant>[];
    return Row(
      children: [
        Expanded(
          child: _messages.isEmpty && pendingRequests.isEmpty && _chatLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: pendingRequests.length + _messages.length,
                  itemBuilder: (context, index) {
                    if (index < pendingRequests.length) {
                      return _joinRequestCard(pendingRequests[index]);
                    }
                    final msg = _messages[index - pendingRequests.length];
                    final mine = msg.senderId == _currentUserId;
                    final sender = _participantByUserId(msg.senderId);
                    return _chatMessageRow(
                      message: msg,
                      mine: mine,
                      sender: sender,
                    );
                  },
                ),
        ),
        const SizedBox(width: 10),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: participants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    final avatarUrl = _validUrlOrNull(p.profilePictureUrl);
                    return Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _openParticipantProfile(p),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _participantStatusColor(p.status),
                              width: 1.3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(
                                    _initialsFrom(_participantDisplayName(p)),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chatAccessInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          "Masaya katılma talebin şu an beklemede. Kabul edildiğinde ya da reddedildiğinde sana hemen haber vereceğiz. Durumu 'Mesajlar > Müzik Birleştirir!' kısmından kontrol edebilirsin.",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  String _timeOf(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  bool get _showActionsCard {
    if (_isOwner) return false;
    if (_myStatus == null) return true;
    if (_myStatus == TableGroupParticipantStatus.pending) return true;
    return _isAccepted;
  }

  List<TableGroupParticipant> get _pendingJoinRequests {
    final group = _group;
    if (group == null) return const <TableGroupParticipant>[];
    final pending = group.participants
        .where(
          (participant) =>
              participant.status == TableGroupParticipantStatus.pending &&
              participant.userId != group.ownerId,
        )
        .toList();
    pending.sort((a, b) {
      final aa = a.joinedAt?.millisecondsSinceEpoch ?? 0;
      final bb = b.joinedAt?.millisecondsSinceEpoch ?? 0;
      return bb.compareTo(aa);
    });
    return pending;
  }

  String _participantDisplayName(TableGroupParticipant participant) {
    final username = participant.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    final shortId = participant.userId.length > 8
        ? participant.userId.substring(0, 8)
        : participant.userId;
    return shortId;
  }

  String _displayNameForSender(
    TableGroupParticipant? sender,
    String senderUserId,
  ) {
    if (sender != null) return _participantDisplayName(sender);
    return senderUserId.length > 8
        ? senderUserId.substring(0, 8)
        : senderUserId;
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

  Color _participantStatusColor(TableGroupParticipantStatus status) {
    return switch (status) {
      TableGroupParticipantStatus.accepted => const Color(0xFF2FB46E),
      TableGroupParticipantStatus.pending => const Color(0xFFE0A200),
      TableGroupParticipantStatus.rejected => const Color(0xFFD06363),
      TableGroupParticipantStatus.kicked => const Color(0xFFD06363),
      TableGroupParticipantStatus.left => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
  }

  Future<void> _openParticipantProfile(
    TableGroupParticipant participant,
  ) async {
    if (!mounted) return;
    final resolver = serviceLocator<DmUserProfileResolver>();
    final resolvedTargets = await resolver.resolveByUserId(
      userId: participant.userId,
      usernameHint: participant.username,
    );
    if (!mounted) return;
    final targets = resolvedTargets
        .where((target) => dmProfileRouteFor(target) != null)
        .toList(growable: false);
    if (targets.isEmpty) {
      _showSnack('Bu kullanici icin acik profil bulunamadi');
      return;
    }
    if (targets.length == 1) {
      _navigateToProfileTarget(targets.first);
      return;
    }
    final selected = await showModalBottomSheet<DmProfileTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => _TableGroupProfileTargetSheet(items: targets),
    );
    if (!mounted || selected == null) return;
    _navigateToProfileTarget(selected);
  }

  void _navigateToProfileTarget(DmProfileTarget target) {
    final route = dmProfileRouteFor(target);
    if (route == null) return;
    Navigator.of(
      context,
    ).pushNamed(route.routeName, arguments: route.arguments);
  }

  Future<void> _approvePendingRequest(TableGroupParticipant participant) async {
    await _runOwnerAction(
      participantId: participant.userId,
      fn: () => _approve(participant.userId),
    );
  }

  Future<void> _rejectPendingRequest(TableGroupParticipant participant) async {
    await _runOwnerAction(
      participantId: participant.userId,
      fn: () => _reject(participant.userId),
    );
  }

  Widget _joinRequestCard(TableGroupParticipant participant) {
    final avatarUrl = _validUrlOrNull(participant.profilePictureUrl);
    final loading = _ownerActionInFlightIds.contains(participant.userId);
    final displayName = _participantDisplayName(participant);
    return CustomPaint(
      painter: _GradientOutlinePainter(
        radius: 14,
        strokeWidth: 1.2,
        colors: AppColors.brandGradient,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      _initialsFrom(displayName),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yeni katilma istegi',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (loading)
              const SizedBox(
                width: 32,
                height: 32,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _requestActionIcon(
                icon: Icons.check_rounded,
                color: const Color(0xFF2FB46E),
                onTap: () => _approvePendingRequest(participant),
              ),
              const SizedBox(width: 6),
              _requestActionIcon(
                icon: Icons.close_rounded,
                color: const Color(0xFFE45656),
                onTap: () => _rejectPendingRequest(participant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _requestActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.25),
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _brandOutlineButton({
    required String label,
    required VoidCallback? onTap,
    bool compact = false,
  }) {
    final disabled = onTap == null;
    const radius = 18.0;
    final borderColors = disabled
        ? [
            Theme.of(context).dividerColor.withValues(alpha: 0.7),
            Theme.of(context).dividerColor.withValues(alpha: 0.7),
          ]
        : AppColors.brandGradient;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: CustomPaint(
          painter: _GradientOutlinePainter(
            radius: radius,
            strokeWidth: 1.3,
            colors: borderColors,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: disabled
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableGroupParticipant? _participantByUserId(String userId) {
    final group = _group;
    if (group == null) return null;
    for (final participant in group.participants) {
      if (participant.userId == userId) return participant;
    }
    return null;
  }

  Widget _chatMessageRow({
    required TableGroupMessage message,
    required bool mine,
    required TableGroupParticipant? sender,
  }) {
    final avatarUrl = sender == null
        ? null
        : _validUrlOrNull(sender.profilePictureUrl);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: mine
            ? LinearGradient(colors: [AppColors.gradientA, AppColors.gradientC])
            : null,
        color: mine
            ? null
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(mine ? 14 : 6),
          bottomRight: Radius.circular(mine ? 6 : 14),
        ),
        border: Border.all(
          color: mine ? Colors.transparent : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            _timeOf(message.sentAt),
            style: TextStyle(
              fontSize: 11,
              color: mine
                  ? AppColors.white.withValues(alpha: 0.84)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (mine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    _initialsFrom(
                      _displayNameForSender(sender, message.senderId),
                    ),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          bubble,
        ],
      ),
    );
  }
}

class _TableGroupProfileTargetSheet extends StatelessWidget {
  final List<DmProfileTarget> items;

  const _TableGroupProfileTargetSheet({required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final imageUrl = item.imageUrl?.trim();
          final hasImage =
              imageUrl != null &&
              (imageUrl.startsWith('http://') ||
                  imageUrl.startsWith('https://'));
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
              child: hasImage
                  ? null
                  : Icon(switch (item.type) {
                      DmProfileTargetType.musician => Icons.person_outline,
                      DmProfileTargetType.venue => Icons.storefront_outlined,
                      DmProfileTargetType.studio => Icons.graphic_eq_outlined,
                      DmProfileTargetType.listener => Icons.headphones_outlined,
                    }, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            title: Text(item.displayName),
            subtitle: Text(item.type.displayLabel),
            onTap: () => Navigator.of(context).pop(item),
          );
        },
      ),
    );
  }
}

class _GradientOutlinePainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final List<Color> colors;

  _GradientOutlinePainter({
    required this.radius,
    required this.strokeWidth,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(colors: colors).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientOutlinePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.colors != colors;
  }
}
