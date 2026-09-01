import 'entities/table_group.dart';

bool isTableGroupSessionActiveAt(TableGroup? group, DateTime now) {
  if (group == null || group.status.trim().toUpperCase() != 'ACTIVE') {
    return false;
  }
  final expiresAt = group.expiresAt;
  return expiresAt != null && expiresAt.isAfter(now);
}

Duration? tableGroupTimeUntilExpiry(TableGroup? group, DateTime now) {
  if (!isTableGroupSessionActiveAt(group, now)) return null;
  return group!.expiresAt!.difference(now);
}
