import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../../engagement/presentation/cubit/interaction_stats_cubit.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/profile_media_management_repository.dart';
import '../cubit/profile_media_cubit.dart';
import 'profile_count_row.dart';
import 'profile_screen_support.dart';
import 'video_reel_screen.dart';

part 'profile_owner_video_tab_methods.dart';

class ProfileOwnerVideoTab extends StatefulWidget {
  final List<MediaAsset> items;
  final String profileId;
  final bool ownerMode;
  final String profileType;
  final String uploadOwnerType;

  ProfileOwnerVideoTab({
    super.key,
    required this.items,
    required this.profileId,
    required this.ownerMode,
    required this.profileType,
    required this.uploadOwnerType,
  });

  @override
  State<ProfileOwnerVideoTab> createState() => _ProfileOwnerVideoTabState();
}

class _ProfileOwnerVideoTabState extends State<ProfileOwnerVideoTab> {
  final Set<String> _processingVideoIds = <String>{};
  Timer? _processingPollTimer;
  bool _pollBusy = false;
  int _pollAttempt = 0;
  static int _maxPollAttempt = 45;
  bool _videoUploading = false;

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  @override
  void initState() {
    super.initState();
    _syncProcessingState();
  }

  @override
  void didUpdateWidget(covariant ProfileOwnerVideoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncProcessingState();
  }

  @override
  void dispose() {
    _processingPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ownerMode) {
      final hasAny = widget.items.isNotEmpty;
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, hasAny ? 8 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _videoUploading ? null : _pickAndUploadVideo,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      Color(0x1AFFFFFF),
                      Color(0x1A8A5CFF),
                      Color(0x1AFF7A3D),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 28,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      hasAny ? 'Video ekle' : 'Henuz video eklemediniz',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'SoundConnect uzerinden video yuklemek icin dokun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (_videoUploading) ...[
                      SizedBox(height: 10),
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_processingVideoIds.isNotEmpty) _buildProcessingCard(),
          if (widget.items.isEmpty && _processingVideoIds.isEmpty)
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Henuz video eklemediniz.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else if (widget.items.isNotEmpty)
            GridView.builder(
              padding: EdgeInsets.all(20),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: widget.items.length,
              itemBuilder: (context, index) =>
                  _buildVideoCard(context, widget.items[index], index),
            ),
        ],
      );
    }

    if (widget.items.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Kullanici henuz video eklemedi.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(20),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, index) =>
          _buildVideoCard(context, widget.items[index], index),
    );
  }
}
