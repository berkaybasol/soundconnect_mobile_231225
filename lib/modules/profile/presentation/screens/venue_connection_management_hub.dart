import 'package:flutter/material.dart';
import '../../../../shared/widgets/profile_management_sheet.dart';

enum VenueConnectionManagementDestination { create, incoming, outgoing }

Future<VenueConnectionManagementDestination?> showVenueConnectionManagementHub(
  BuildContext context,
) => showProfileManagementSheet<VenueConnectionManagementDestination>(
  context,
  title: 'Mekan Bağlantılarını Yönet',
  options: const [
    ProfileManagementSheetOption(
      key: Key('venue-connection-management-create'),
      value: VenueConnectionManagementDestination.create,
      icon: Icons.add_business_outlined,
      label: 'Mekan Bağlantısı Oluştur',
    ),
    ProfileManagementSheetOption(
      key: Key('venue-connection-management-incoming'),
      value: VenueConnectionManagementDestination.incoming,
      icon: Icons.inbox_outlined,
      label: 'Gelen Mekan İstekleri',
    ),
    ProfileManagementSheetOption(
      key: Key('venue-connection-management-outgoing'),
      value: VenueConnectionManagementDestination.outgoing,
      icon: Icons.send_outlined,
      label: 'Gönderdiğim İstekler',
    ),
  ],
);
