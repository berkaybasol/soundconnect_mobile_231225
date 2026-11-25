import 'package:flutter/material.dart';

import '../../../../core/utils/turkish_date_label.dart';
import '../../domain/admin_user_directory.dart';
import '../../domain/pending_application.dart';
import 'admin_user_directory_widgets.dart';
import 'admin_visual_theme.dart';
import 'application_review_widgets.dart';

class AdminUserDetailView extends StatelessWidget {
  const AdminUserDetailView({
    super.key,
    required this.detail,
    required this.onOpenProfile,
    required this.onCopy,
    this.onChangeAccess,
    this.decisionNotice,
  });

  final AdminUserDetail detail;
  final VoidCallback onOpenProfile;
  final void Function(String value, String label) onCopy;
  final VoidCallback? onChangeAccess;
  final String? decisionNotice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = detail.account;
    final application = detail.lastApplicationStatus;
    final createdAt = detail.createdAt;
    final businessApplicant =
        (account.profileType == AdminUserProfileType.studio ||
            account.profileType == AdminUserProfileType.venue) &&
        (application == ApplicationReviewStatus.pending ||
            application == ApplicationReviewStatus.rejected);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            'Hesap detayı',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.9,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            AdminUserTypeIcon(type: account.profileType, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${account.username}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    account.profileType.label,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ApplicationSurface(
          rows: [
            _Fact('Hesap durumu', account.status.label),
            if (application != null)
              _Fact(
                'Son başvuru',
                application == ApplicationReviewStatus.pending
                    ? 'İnceleniyor'
                    : application.label,
              ),
            _Fact(
              'Kayıt tarihi',
              createdAt == null
                  ? 'Kayıtlı değil'
                  : turkishDateLabel(createdAt.toLocal()),
            ),
            _Fact(
              'E-posta doğrulaması',
              detail.emailVerified ? 'Doğrulandı' : 'Doğrulanmadı',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (detail.accessRevision != null) ...[
          Semantics(
            header: true,
            child: Text('Hesap erişimi', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          ApplicationSurface(
            rows: [
              _Fact('Erişim durumu', account.suspended ? 'Askıda' : 'Askı yok'),
              if (detail.lastAccessDecision case final decision?) ...[
                _Fact(
                  'Son karar',
                  decision.suspended
                      ? 'Hesap askıya alındı'
                      : 'Askı kaldırıldı',
                ),
                _Fact('Yönetici', '@${decision.actorUsername}'),
                _Fact(
                  'Karar zamanı',
                  _decisionTime(decision.decidedAt.toLocal()),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yönetici gerekçesi',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(decision.reason),
                    ],
                  ),
                ),
              ],
              if (detail.canManageAccess)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton(
                    onPressed: onChangeAccess,
                    style: account.suspended
                        ? null
                        : OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                    child: Text(
                      account.suspended ? 'Askıyı kaldır' : 'Hesabı askıya al',
                    ),
                  ),
                ),
            ],
          ),
          if (decisionNotice case final notice?)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(notice),
              ),
            ),
          const SizedBox(height: 16),
        ],
        Semantics(
          header: true,
          child: Text(
            'Hesap kimlikleri',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ApplicationSurface(
          rows: [
            _Identifier(
              'Hesap kimliği',
              account.userId,
              'Hesap kimliğini kopyala',
              onCopy,
            ),
            _Identifier(
              'Kullanıcı kodu',
              detail.publicCode,
              'Kullanıcı kodunu kopyala',
              onCopy,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (detail.profileId != null)
          AdminBrandButton(
            label: 'Profili aç',
            icon: Icons.north_east,
            onPressed: onOpenProfile,
          )
        else
          Text(
            businessApplicant
                ? 'İşletme profili henüz oluşturulmadı.'
                : 'Bu hesap için görüntülenebilir bir profil yok.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

String _decisionTime(DateTime date) =>
    '${turkishDateLabel(date)} · ${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Identifier extends StatelessWidget {
  const _Identifier(this.label, this.value, this.tooltip, this.onCopy);

  final String label;
  final String value;
  final String tooltip;
  final void Function(String value, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tooltip,
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () => onCopy(value, label),
          ),
        ],
      ),
    );
  }
}
