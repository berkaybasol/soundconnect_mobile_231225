part of 'listener_account_deletion_dialog.dart';

class _DeletionHeader extends StatelessWidget {
  const _DeletionHeader({required this.verifying, required this.colors});

  final bool verifying;
  final AppColorPalette colors;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF33212D) : const Color(0xFFFFEDF0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 24,
                color: dark ? const Color(0xFFFF8795) : const Color(0xFFA82D46),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              verifying ? '2 / 2' : '1 / 2',
              semanticsLabel: verifying
                  ? 'İkinci adım, toplam iki adım'
                  : 'İlk adım, toplam iki adım',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            verifying ? 'Kimliğini doğrula' : 'Hesabını sil',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 27,
              height: 1.13,
              letterSpacing: -.8,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          verifying
              ? 'Hesabını silmek için giriş yaptığın yöntemi kullan.'
              : 'Hesabın hemen silinir ve oturumun kapanır. Bu işlem geri alınamaz.',
          style: TextStyle(fontSize: 14, height: 1.42, color: colors.textMuted),
        ),
      ],
    );
  }
}

class _DeletionEffects extends StatelessWidget {
  const _DeletionEffects({required this.colors, required this.profile});

  final AppColorPalette colors;
  final AccountDeletionProfile? profile;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.symmetric(horizontal: BorderSide(color: colors.border)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          _effect(
            Icons.person_remove_outlined,
            'Profilin ve paylaşımların kaldırılır',
            'Profil fotoğrafın, yazıların ve kişisel kimlik bilgilerin silinir.',
          ),
          if (profile == AccountDeletionProfile.musician) ...[
            const SizedBox(height: 12),
            _effect(
              Icons.music_note_outlined,
              'Müzisyen profilin kaldırılır',
              'Kişisel yayınların ve açtığın ilanlar kaldırılır. Band üyeliklerin sona erer.',
            ),
          ],
          if (profile == AccountDeletionProfile.venue) ...[
            const SizedBox(height: 12),
            _effect(
              Icons.event_busy_outlined,
              'Mekânın programı kapanır',
              'Mekânın düzenlediği gelecek etkinlikler iptal edilir ve tekrarlı program durur.',
            ),
          ],
          if (profile == AccountDeletionProfile.studio) ...[
            const SizedBox(height: 12),
            _effect(
              Icons.meeting_room_outlined,
              'Stüdyonun odaları kapanır',
              'Gelecekteki bekleyen ve onaylı rezervasyonlar iptal edilir. Müşterilere bildirim gönderilir.',
            ),
          ],
          const SizedBox(height: 12),
          _effect(
            Icons.forum_outlined,
            'Mesaj geçmişi karşı tarafta kalır',
            'Mesajlarında adın “Silinmiş hesap” olarak görünür.',
          ),
        ],
      ),
    ),
  );

  Widget _effect(IconData icon, String title, String details) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 19, color: colors.textMuted),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              details,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

String _decisionSummary(
  BandDeletionOption band,
  BandDeletionDecision decision,
) {
  if (decision.successorUserId == null) return '${band.bandName} kapatılacak.';
  final member = band.successors.singleWhere(
    (s) => s.userId == decision.successorUserId,
  );
  return '${band.bandName} kuruculuğu @${member.username} kullanıcısına devredilecek.';
}

class _BandDeletionChoice extends StatelessWidget {
  const _BandDeletionChoice({
    required this.option,
    required this.selection,
    required this.onChanged,
  });

  final BandDeletionOption option;
  final BandDeletionDecision? selection;
  final ValueChanged<BandDeletionDecision> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(option.bandName, style: Theme.of(context).textTheme.titleMedium),
        Text(
          option.successors.isEmpty
              ? 'Bu bandın son kurucususun. Devralabilecek aktif üye yok.'
              : 'Bu bandın son kurucususun. Kuruculuğu bir üyeye devredebilir veya bandı kapatabilirsin.',
        ),
        DropdownButton<BandDeletionDecision>(
          key: ValueKey('band-decision-${option.bandId}'),
          value: selection,
          hint: const Text('Band için seçim yap'),
          isExpanded: true,
          items: [
            for (final member in option.successors)
              DropdownMenuItem(
                value: (bandId: option.bandId, successorUserId: member.userId),
                child: Text(
                  '@${member.username} kullanıcısına devret',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            DropdownMenuItem(
              value: (bandId: option.bandId, successorUserId: null),
              child: const Text('Bandı kalıcı olarak kapat'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    ),
  );
}

class _DeletionMethodSelector extends StatelessWidget {
  const _DeletionMethodSelector({
    required this.colors,
    required this.google,
    required this.onChanged,
  });

  final AppColorPalette colors;
  final bool google;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Hesabını açtığın yöntem',
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.inputFill,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _choice(
              context,
              false,
              'Şifre',
              const Icon(Icons.key_outlined, size: 18),
            ),
            const SizedBox(width: 3),
            _choice(
              context,
              true,
              'Google',
              Image.asset(
                'assets/google.png',
                width: 18,
                height: 18,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ],
  );

  Widget _choice(BuildContext context, bool value, String label, Widget icon) {
    final selected = value == google;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton.icon(
          onPressed: onChanged == null ? null : () => onChanged!(value),
          icon: icon,
          label: Text(label, textAlign: TextAlign.center),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            backgroundColor: selected
                ? (dark ? const Color(0xFF303B4E) : Colors.white)
                : null,
            foregroundColor: selected ? colors.textPrimary : colors.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: selected ? colors.border : Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
