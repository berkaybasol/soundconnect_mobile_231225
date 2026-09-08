import 'package:flutter/material.dart';
import '../../../../shared/widgets/profile_management_sheet.dart';

enum VenueConnectionManagementDestination {
  connections,
  create,
  incoming,
  outgoing,
}

Future<VenueConnectionManagementDestination?> showVenueConnectionManagementHub(
  BuildContext context, {
  bool artistConnections = false,
}) => showProfileManagementSheet<VenueConnectionManagementDestination>(
  context,
  title: artistConnections ? 'Sanatçı Bağlantıları' : 'Mekan Bağlantıları',
  options: const [
    ProfileManagementSheetOption(
      key: Key('venue-connection-management-connections'),
      value: VenueConnectionManagementDestination.connections,
      icon: Icons.link_rounded,
      label: 'Bağlantılarım',
    ),
    ProfileManagementSheetOption(
      key: Key('venue-connection-management-incoming'),
      value: VenueConnectionManagementDestination.incoming,
      icon: Icons.inbox_outlined,
      label: 'Gelen İstekler',
    ),
    ProfileManagementSheetOption(
      key: Key('venue-connection-management-outgoing'),
      value: VenueConnectionManagementDestination.outgoing,
      icon: Icons.send_outlined,
      label: 'Gönderdiğim İstekler',
    ),
  ],
  primaryAction: ProfileManagementSheetOption(
    key: const Key('venue-connection-management-create'),
    value: VenueConnectionManagementDestination.create,
    icon: artistConnections
        ? Icons.person_add_alt_1_outlined
        : Icons.add_business_outlined,
    label: artistConnections ? 'Sanatçı ekle' : 'Mekan ekle',
  ),
);
