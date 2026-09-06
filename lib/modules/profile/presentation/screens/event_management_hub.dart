import 'package:flutter/material.dart';
import '../../../../shared/widgets/profile_management_sheet.dart';

enum EventManagementDestination { invitations, events, rejected }

Future<EventManagementDestination?> showEventManagementHub(
  BuildContext context,
) => showProfileManagementSheet<EventManagementDestination>(
  context,
  title: 'Etkinlik Yönetimi',
  options: const [
    ProfileManagementSheetOption(
      key: Key('event-management-invitations'),
      value: EventManagementDestination.invitations,
      icon: Icons.mark_email_unread_outlined,
      label: 'Etkinlik Davetleri',
    ),
    ProfileManagementSheetOption(
      key: Key('event-management-events'),
      value: EventManagementDestination.events,
      icon: Icons.calendar_month_outlined,
      label: 'Etkinliklerim',
    ),
    ProfileManagementSheetOption(
      key: Key('event-management-rejected'),
      value: EventManagementDestination.rejected,
      icon: Icons.event_busy_outlined,
      label: 'Reddedilen Etkinlikler',
    ),
  ],
);
