import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/admin_venue_application.dart';
import '../cubit/admin_panel_cubit.dart';
import '../cubit/admin_panel_state.dart';

class AdminVenueApplicationFilters extends StatelessWidget {
  const AdminVenueApplicationFilters({super.key, required this.state});

  final AdminPanelState state;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AdminVenueApplicationStatus>(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.coralAlt.withValues(alpha: 0.20);
          }
          return AppColors.navBlueSoft.withValues(alpha: 0.60);
        }),
        foregroundColor: WidgetStatePropertyAll(AppColors.textPrimary),
        side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
      ),
      segments: const [
        ButtonSegment(
          value: AdminVenueApplicationStatus.pending,
          icon: Icon(Icons.pending_actions_outlined),
          label: Text('Bekleyen'),
        ),
        ButtonSegment(
          value: AdminVenueApplicationStatus.approved,
          icon: Icon(Icons.verified_outlined),
          label: Text('Onay'),
        ),
        ButtonSegment(
          value: AdminVenueApplicationStatus.rejected,
          icon: Icon(Icons.block_outlined),
          label: Text('Red'),
        ),
      ],
      selected: {state.selectedStatus},
      onSelectionChanged: (selection) {
        context.read<AdminPanelCubit>().loadVenueApplications(selection.first);
      },
    );
  }
}

class AdminStudioApplicationFilters extends StatelessWidget {
  const AdminStudioApplicationFilters({super.key, required this.state});

  final AdminPanelState state;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AdminVenueApplicationStatus>(
      segments: const [
        ButtonSegment(
          value: AdminVenueApplicationStatus.pending,
          label: Text('Bekleyen'),
        ),
        ButtonSegment(
          value: AdminVenueApplicationStatus.approved,
          label: Text('Onaylanan'),
        ),
        ButtonSegment(
          value: AdminVenueApplicationStatus.rejected,
          label: Text('Reddedilen'),
        ),
      ],
      selected: {state.selectedStatus},
      onSelectionChanged: (selection) => context
          .read<AdminPanelCubit>()
          .loadStudioApplications(selection.first),
    );
  }
}
