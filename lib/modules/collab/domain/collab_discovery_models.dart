import 'collab_types.dart';

export 'collab_types.dart'
    show CollabCadence, CollabCadenceX, CollabProfileKind, CollabProfileKindX;

/// Presentation-only shape shared by the discovery card and create preview.
/// Filtering and lifecycle decisions stay in the server-backed domain model.
class CollabDiscoveryListing {
  const CollabDiscoveryListing({
    required this.id,
    required this.ownerName,
    required this.ownerInitials,
    required this.profileKind,
    required this.wantedKind,
    required this.title,
    required this.cadence,
    required this.location,
    required this.role,
    this.scheduledAt,
    this.feeAmountMinor,
    this.feeCurrency,
    this.ownerSpecialty,
    this.avatarAsset,
    this.avatarUrl,
    this.isHighlighted = false,
  });

  final String id;
  final String ownerName;
  final String ownerInitials;
  final CollabProfileKind profileKind;
  final CollabProfileKind wantedKind;
  final String? ownerSpecialty;
  final String? avatarAsset;
  final String? avatarUrl;
  final String title;
  final CollabCadence cadence;
  final String location;
  final String role;
  final DateTime? scheduledAt;
  final int? feeAmountMinor;
  final String? feeCurrency;
  final bool isHighlighted;

  String get ownerSubtitle {
    final specialty = ownerSpecialty?.trim();
    if (specialty == null || specialty.isEmpty) return profileKind.label;
    return '${profileKind.label} · $specialty';
  }

  String get wantedSummary {
    final label = wantedKind.wantedLabel;
    final specialty = role.trim();
    if (wantedKind != CollabProfileKind.musician || specialty.isEmpty) {
      return label;
    }
    return '$label: $specialty';
  }
}
