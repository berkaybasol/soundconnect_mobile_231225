import 'package:flutter/material.dart';

import '../../domain/admin_user_directory.dart';

class AdminUserTypeIcon extends StatelessWidget {
  const AdminUserTypeIcon({super.key, required this.type, this.size = 36});
  final AdminUserProfileType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (icon, tint) = switch (type) {
      AdminUserProfileType.listener => (
        Icons.headphones,
        dark ? const Color(0xff9bdbc8) : const Color(0xff326c5b),
      ),
      AdminUserProfileType.musician => (
        Icons.music_note_outlined,
        dark ? const Color(0xffffaba5) : const Color(0xff963e4c),
      ),
      AdminUserProfileType.venue => (
        Icons.storefront_outlined,
        dark ? const Color(0xffe7bc84) : const Color(0xff7d572d),
      ),
      AdminUserProfileType.studio => (
        Icons.tune_rounded,
        dark ? const Color(0xffc6b4f1) : const Color(0xff67508c),
      ),
    };
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: size * .50, color: tint),
    );
  }
}

class AdminUserRow extends StatelessWidget {
  const AdminUserRow({super.key, required this.account, required this.onTap});
  final AdminUserAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final statusColor = switch (account.status) {
      AdminUserStatus.active =>
        dark ? const Color(0xff9ed5bc) : const Color(0xff20674d),
      AdminUserStatus.inactive => theme.colorScheme.onSurfaceVariant,
      _ => dark ? const Color(0xffe9bd88) : const Color(0xff855827),
    };
    final status = Text(
      account.suspended ? 'Askıda' : account.status.label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: account.suspended ? theme.colorScheme.error : statusColor,
        fontWeight: FontWeight.w700,
      ),
    );
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              AdminUserTypeIcon(type: account.profileType),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${account.username}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      account.profileType.label,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (largeText) status,
                  ],
                ),
              ),
              if (!largeText) ...[
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 86),
                  child: status,
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminUserFilter<T extends Enum> extends StatelessWidget {
  const AdminUserFilter({
    super.key,
    required this.label,
    required this.values,
    required this.value,
    required this.labelFor,
    required this.onChanged,
  });
  final String label;
  final List<T> values;
  final T? value;
  final String Function(T) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <T?>[null, ...values];
    String text(T? option) => option == null ? 'Tümü' : labelFor(option);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          hint: const Text('Tümü'),
          isExpanded: true,
          itemHeight: null,
          style: Theme.of(context).textTheme.bodyMedium,
          selectedItemBuilder: (_) => [
            for (final item in options)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          items: [
            for (final item in options)
              DropdownMenuItem<T?>(
                value: item,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(text(item)),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
