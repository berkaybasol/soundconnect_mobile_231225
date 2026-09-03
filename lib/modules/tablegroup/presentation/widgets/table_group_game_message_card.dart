import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../domain/entities/table_group_game.dart';
import '../../domain/entities/table_group_message.dart';
import '../table_group_game_copy.dart';
import 'table_group_game_countdown.dart';

typedef TableGroupGameActionCallback =
    void Function(TableGroupGameAction action, String? targetUserId);

class TableGroupGameMessageCard extends StatelessWidget {
  const TableGroupGameMessageCard({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.canCancelGame,
    required this.actionInFlight,
    this.actionCommitted = false,
    this.interactionEnabled = true,
    required this.onJoin,
    required this.onLeave,
    required this.onStart,
    required this.onCancel,
    required this.onAction,
    required this.onExpired,
    this.now,
  });

  final TableGroupMessage message;
  final String? currentUserId;
  final bool canCancelGame;
  final bool actionInFlight;
  final bool actionCommitted;
  final bool interactionEnabled;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final TableGroupGameActionCallback onAction;
  final VoidCallback onExpired;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final game = message.game;
    if (game == null) return Text(message.content);
    final currentPlayer = game.playerFor(currentUserId);
    final joined = currentPlayer?.hasJoined == true;
    final isCreator = currentUserId != null && game.createdBy == currentUserId;
    final joinedPlayers = game.players
        .where((player) => player.hasJoined)
        .toList(growable: false);

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          key: ValueKey<String>('table-group-game-${game.gameId}'),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.brandGradient
                  .map((color) => color.withValues(alpha: 0.62))
                  .toList(growable: false),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1526),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.topic == TableGroupGameTopic.whoPays
                                  ? '🎮 Hesap Kimde?'
                                  : '🎮 Oyun',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _modeLabel(game.mode),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (interactionEnabled &&
                          !game.isTerminal &&
                          game.phaseDeadline != null)
                        TableGroupGameCountdown(
                          deadline: game.phaseDeadline!,
                          serverTime: game.serverTime,
                          expiryToken:
                              '${game.gameId}:${game.revision}:${game.phase.name}:'
                              '${game.phaseDeadline!.microsecondsSinceEpoch}',
                          onExpired: onExpired,
                          now: now,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!game.isTerminal && !game.supportsWhoPaysInteraction)
                    _info(
                      context,
                      'Bu oyun sürümü henüz desteklenmiyor. '
                      'Uygulamayı güncelleyip tekrar deneyebilirsin.',
                    )
                  else if (!game.isTerminal && !interactionEnabled)
                    _info(context, 'Bu oyun artık aktif değil.')
                  else if (game.isLobby)
                    _lobby(
                      context,
                      game,
                      joinedPlayers,
                      joined: joined,
                      isCreator: isCreator,
                      canCancel: canCancelGame,
                    )
                  else if (game.status == TableGroupGameStatus.completed)
                    _completed(context, game)
                  else if (game.status == TableGroupGameStatus.cancelled)
                    _cancelled(context, game)
                  else
                    _inProgress(context, game, currentPlayer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lobby(
    BuildContext context,
    TableGroupGame game,
    List<TableGroupGamePlayer> joinedPlayers, {
    required bool joined,
    required bool isCreator,
    required bool canCancel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Katılım için 3 dakika var. En az 2 oyuncu gerekli.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: joinedPlayers
              .map(
                (player) =>
                    _playerPill(context, player, icon: Icons.person_rounded),
              )
              .toList(growable: false),
        ),
        if (joinedPlayers.isEmpty)
          const Text('Henüz katılan olmadı.', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!joined)
              FilledButton.icon(
                key: const ValueKey<String>('table-group-game-join'),
                onPressed: actionInFlight ? null : onJoin,
                style: _filledStyle(context),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Katıl'),
              ),
            if (joined && !isCreator)
              OutlinedButton(
                key: const ValueKey<String>('table-group-game-leave'),
                onPressed: actionInFlight ? null : onLeave,
                style: _outlinedStyle(context),
                child: const Text('Oyundan ayrıl'),
              ),
            if (isCreator)
              FilledButton(
                key: const ValueKey<String>('table-group-game-start'),
                onPressed: actionInFlight || joinedPlayers.length < 2
                    ? null
                    : onStart,
                style: _filledStyle(context),
                child: const Text('Şimdi başlat'),
              ),
            if (canCancel)
              TextButton(
                key: const ValueKey<String>('table-group-game-cancel'),
                onPressed: actionInFlight ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Oyunu iptal et'),
              ),
          ],
        ),
        if (actionInFlight) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }

  Widget _inProgress(
    BuildContext context,
    TableGroupGame game,
    TableGroupGamePlayer? currentPlayer,
  ) {
    final canAct = currentPlayer?.canAct == true;
    final hasActed = currentPlayer?.hasActed == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tur ${game.round}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (game.phase == TableGroupGamePhase.vote) _voteWarning(context),
        if (currentPlayer == null || !currentPlayer.hasJoined)
          _info(context, 'Bu oyunu izliyorsun.')
        else if (currentPlayer.status == TableGroupGamePlayerStatus.safe)
          _info(context, 'Bu tur güvendesin. 😌')
        else if (currentPlayer.status == TableGroupGamePlayerStatus.timedOut)
          _info(context, 'Hamle süren doldu; bu turu izliyorsun.')
        else if (hasActed || actionCommitted)
          _info(context, 'Hamlen alındı. Diğer oyuncular bekleniyor.')
        else if (canAct)
          _actionPanel(context, game),
        const SizedBox(height: 10),
        _actedPlayers(context, game),
        if (game.revealedActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _reveals(context, game),
        ],
        if (actionInFlight) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (canCancelGame) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: actionInFlight ? null : onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Oyunu iptal et'),
          ),
        ],
      ],
    );
  }

  Widget _actionPanel(BuildContext context, TableGroupGame game) {
    return switch (game.phase) {
      TableGroupGamePhase.rockPaperScissors => Wrap(
        alignment: WrapAlignment.center,
        spacing: 7,
        runSpacing: 7,
        children: [
          _actionButton(
            key: 'game-action-rock',
            label: '✊ Taş',
            action: TableGroupGameAction.rock,
          ),
          _actionButton(
            key: 'game-action-paper',
            label: '✋ Kağıt',
            action: TableGroupGameAction.paper,
          ),
          _actionButton(
            key: 'game-action-scissors',
            label: '✌️ Makas',
            action: TableGroupGameAction.scissors,
          ),
        ],
      ),
      TableGroupGamePhase.dice => Center(
        child: _actionButton(
          key: 'game-action-roll',
          label: '🎲 Zarı at',
          action: TableGroupGameAction.roll,
          filled: true,
        ),
      ),
      TableGroupGamePhase.voteTieDice => Column(
        children: [
          const Text(
            'Beraberlik! Eşit oy alanlar zar atsın. 🎲',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _actionButton(
            key: 'game-action-tie-roll',
            label: '🎲 Zarı at',
            action: TableGroupGameAction.roll,
            filled: true,
          ),
        ],
      ),
      TableGroupGamePhase.vote => _voteChoices(context, game),
      _ => _info(context, 'Sonraki aşama bekleniyor.'),
    };
  }

  Widget _actionButton({
    required String key,
    required String label,
    required TableGroupGameAction action,
    bool filled = false,
  }) {
    final onPressed = actionInFlight ? null : () => onAction(action, null);
    if (filled) {
      return FilledButton(
        key: ValueKey<String>(key),
        onPressed: onPressed,
        style: _filledStyle(null),
        child: Text(label),
      );
    }
    return OutlinedButton(
      key: ValueKey<String>(key),
      onPressed: onPressed,
      style: _outlinedStyle(null),
      child: Text(label),
    );
  }

  Widget _voteChoices(BuildContext context, TableGroupGame game) {
    final viewerId = currentUserId?.trim();
    final candidates = game.players
        .where((player) => player.canAct)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const ValueKey<String>('game-action-volunteer'),
          onPressed: actionInFlight
              ? null
              : () => onAction(TableGroupGameAction.volunteer, null),
          style: _outlinedStyle(context, emphasized: true),
          icon: const Icon(Icons.volunteer_activism_rounded),
          label: const Text(TableGroupGameCopy.volunteerOption),
        ),
        for (final candidate in candidates) ...[
          const SizedBox(height: 6),
          OutlinedButton(
            key: ValueKey<String>('game-vote-${candidate.userId}'),
            onPressed: actionInFlight
                ? null
                : () => onAction(TableGroupGameAction.vote, candidate.userId),
            style: _outlinedStyle(context),
            child: _mentionWidget(
              candidate,
              suffix:
                  viewerId != null &&
                      viewerId.isNotEmpty &&
                      candidate.userId.trim() == viewerId
                  ? ' (sen)'
                  : '',
            ),
          ),
        ],
      ],
    );
  }

  Widget _voteWarning(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF171C32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandGradient.first.withValues(alpha: 0.42),
        ),
      ),
      child: const Text(
        TableGroupGameCopy.voteWarning,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _actedPlayers(BuildContext context, TableGroupGame game) {
    final active = game.players.where((player) => player.canAct).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: active
          .map(
            (player) => Semantics(
              key: ValueKey<String>('game-player-status-${player.userId}'),
              label:
                  '${player.hasActed ? '${_mention(player)} hamlesini yaptı' : '${_mention(player)} henüz hamle yapmadı'}'
                  '${player.isGhost ? ', hayalet profil' : ''}',
              excludeSemantics: true,
              child: _playerPill(
                context,
                player,
                icon: player.hasActed
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_top_rounded,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _reveals(BuildContext context, TableGroupGame game) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF071321),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF263A52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Açılan hamleler',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (final reveal in game.revealedActions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _revealLine(context, game, reveal),
            ),
        ],
      ),
    );
  }

  Widget _completed(BuildContext context, TableGroupGame game) {
    final result = game.resultMessage?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result == null || result.isEmpty ? message.content : result,
          key: const ValueKey<String>('table-group-game-result'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (game.isSelectedUserGhost) ...[
          const SizedBox(height: 7),
          Center(
            child: GhostProfileBadge(
              key: ValueKey<String>(
                'game-selected-ghost-${game.selectedUserId}',
              ),
            ),
          ),
        ],
        if (game.revealedActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _reveals(context, game),
        ],
      ],
    );
  }

  Widget _cancelled(BuildContext context, TableGroupGame game) {
    final reason = switch (game.cancellationReason?.trim().toUpperCase()) {
      'CANCELLED_BY_CREATOR' => 'Oyun, kurucusu tarafından iptal edildi.',
      'CANCELLED_BY_OWNER' => 'Oyun, masa sahibi tarafından iptal edildi.',
      'CREATOR_LEFT' => 'Oyun kurucusu ayrıldığı için oyun sona erdi.',
      'LOBBY_EXPIRED_NOT_ENOUGH_PLAYERS' =>
        'Katılım süresi doldu; yeterli oyuncu olmadığı için oyun iptal edildi.',
      'NOT_ENOUGH_PLAYERS' =>
        'Yeterli oyuncu kalmadığı için oyun iptal edildi.',
      'PLAYER_LEFT' => 'Bir oyuncu ayrıldığı için oyun iptal edildi.',
      'PLAYER_REMOVED' =>
        'Bir oyuncu masadan çıkarıldığı için oyun iptal edildi.',
      'TABLE_CANCELLED' => 'Masa kapatıldığı için oyun sona erdi.',
      'TABLE_OWNER_JOINED_ANOTHER_TABLE' =>
        'Masa sahibi başka bir masaya katıldığı için oyun sona erdi.',
      'TABLE_EXPIRED' => 'Masanın süresi dolduğu için oyun sona erdi.',
      'MAX_ROUNDS_REACHED' =>
        'Beraberlik uzadığı için oyun sonuçsuz sona erdi.',
      _ => 'Oyun iptal edildi.',
    };
    return _info(context, reason);
  }

  Widget _info(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF071321),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF263A52)),
      ),
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  Widget _revealLine(
    BuildContext context,
    TableGroupGame game,
    TableGroupGameRevealedAction reveal,
  ) {
    final actionText = switch (reveal.action) {
      'ROCK' => ' → ✊ Taş',
      'PAPER' => ' → ✋ Kağıt',
      'SCISSORS' => ' → ✌️ Makas',
      'ROLL' => ' → 🎲 ${reveal.value ?? '?'}',
      'VOLUNTEER' => ' → ${TableGroupGameCopy.volunteerOption}',
      'VOTE' => ' → ',
      _ => ' → ${reveal.action}',
    };
    return Semantics(
      label: _revealSemanticLabel(game, reveal),
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 0,
        runSpacing: 3,
        children: [
          _mentionByIdWidget(game, reveal.actorUserId),
          Text(actionText, style: Theme.of(context).textTheme.bodyMedium),
          if (reveal.action == 'VOTE')
            _mentionByIdWidget(game, reveal.targetUserId),
        ],
      ),
    );
  }

  Widget _mentionByIdWidget(TableGroupGame game, String? userId) {
    final normalized = userId?.trim() ?? '';
    if (normalized.isEmpty) return const Text('@?');
    final player = game.playerFor(normalized);
    return player == null
        ? Text('@${_shortId(normalized)}')
        : _mentionWidget(player);
  }

  Widget _mentionWidget(TableGroupGamePlayer player, {String suffix = ''}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${_mention(player)}$suffix'),
        if (player.isGhost) ...[
          const SizedBox(width: 4),
          GhostProfileBadge(
            key: ValueKey<String>('game-mention-ghost-${player.userId}'),
            showLabel: false,
          ),
        ],
      ],
    );
  }

  String _revealSemanticLabel(
    TableGroupGame game,
    TableGroupGameRevealedAction reveal,
  ) {
    final actor = game.playerFor(reveal.actorUserId);
    final actorMention = actor == null
        ? '@${_shortId(reveal.actorUserId)}'
        : _mention(actor);
    final actorGhost = actor?.isGhost == true ? ', hayalet profil' : '';
    if (reveal.action != 'VOTE') {
      final action = switch (reveal.action) {
        'ROCK' => 'Taş',
        'PAPER' => 'Kağıt',
        'SCISSORS' => 'Makas',
        'ROLL' => 'Zar ${reveal.value ?? '?'}',
        'VOLUNTEER' => TableGroupGameCopy.volunteerOption,
        _ => reveal.action,
      };
      return '$actorMention$actorGhost, $action';
    }
    final target = game.playerFor(reveal.targetUserId);
    final targetId = reveal.targetUserId?.trim() ?? '';
    final targetMention = target == null
        ? '@${targetId.isEmpty ? '?' : _shortId(targetId)}'
        : _mention(target);
    final targetGhost = target?.isGhost == true ? ', hayalet profil' : '';
    return '$actorMention$actorGhost, oy verdi: $targetMention$targetGhost';
  }

  String _mention(TableGroupGamePlayer player) {
    final username = player.username?.trim().replaceFirst(RegExp(r'^@+'), '');
    return '@${username == null || username.isEmpty ? _shortId(player.userId) : username}';
  }

  String _shortId(String value) =>
      value.length > 8 ? value.substring(0, 8) : value;

  Widget _playerPill(
    BuildContext context,
    TableGroupGamePlayer player, {
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111F34),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A4059)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            _mention(player),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (player.isGhost) ...[
            const SizedBox(width: 5),
            GhostProfileBadge(
              key: ValueKey<String>('game-player-ghost-${player.userId}'),
              showLabel: false,
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _outlinedStyle(BuildContext? context, {bool emphasized = false}) {
    final foreground = context == null
        ? AppColors.white
        : Theme.of(context).colorScheme.onSurface;
    return OutlinedButton.styleFrom(
      foregroundColor: foreground,
      backgroundColor: const Color(0xFF071321),
      side: BorderSide(
        color: emphasized
            ? AppColors.brandGradient.first.withValues(alpha: 0.78)
            : const Color(0xFF2A4059),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }

  ButtonStyle _filledStyle(BuildContext? context) {
    final foreground = context == null
        ? AppColors.white
        : Theme.of(context).colorScheme.onPrimary;
    return FilledButton.styleFrom(
      foregroundColor: foreground,
      backgroundColor: AppColors.brandGradient.last,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    );
  }

  String _modeLabel(TableGroupGameMode mode) {
    return switch (mode) {
      TableGroupGameMode.rockPaperScissors => '✊ Taş Kağıt Makas',
      TableGroupGameMode.dice => '🎲 Zar',
      TableGroupGameMode.vote => '🗳️ Oylama',
      TableGroupGameMode.unknown => 'Oyun',
    };
  }
}
