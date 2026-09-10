import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../engagement/domain/engagement_repository.dart';
import '../../../engagement/presentation/cubit/comment_thread_cubit.dart';
import '../../domain/overthinking_repository.dart';
import '../../domain/overthinking_session.dart';
import '../cubit/overthinking_feed_cubit.dart';
import 'overthinking_feed_screen.dart';

final Expando<bool> _openingSource = Expando<bool>();

/// A profile quote is a snapshot. Resolve the source under the current viewer
/// before entering its existing like/comment/reveal surface.
Future<void> openOverthinkingSource(
  BuildContext context,
  String postId, {
  bool Function()? isCurrent,
}) async {
  if (!context.mounted || postId.trim().isEmpty || isCurrent?.call() == false) {
    return;
  }
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent || _openingSource[route] == true) {
    return;
  }
  if (!serviceLocator.isRegistered<OverthinkingRepository>() ||
      !serviceLocator.isRegistered<EngagementRepository>() ||
      !serviceLocator.isRegistered<AuthSessionManager>()) {
    return;
  }
  final manager = serviceLocator<AuthSessionManager>();
  final session = OverthinkingSession(manager);
  if (!session.canWrite) {
    session.dispose();
    return;
  }
  bool current() =>
      context.mounted &&
      route.isCurrent &&
      session.isCurrent &&
      (isCurrent?.call() ?? true);
  _openingSource[route] = true;
  OverthinkingFeedCubit? posts;
  CommentThreadCubit? comments;
  try {
    final repository = serviceLocator<OverthinkingRepository>();
    final engagement = serviceLocator<EngagementRepository>();
    final sourcePosts = OverthinkingFeedCubit(
      overthinkingRepository: repository,
      engagementRepository: engagement,
      sessions: manager,
    );
    posts = sourcePosts;
    await sourcePosts.refreshPost(postId);
    if (!context.mounted || !current()) return;
    final source = sourcePosts.state.posts
        .where((post) => post.id == postId)
        .firstOrNull;
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.info,
          content: Text(
            sourcePosts.state.error?.message ?? 'Bu yazı şu anda açılamıyor.',
          ),
        ),
      );
      return;
    }
    final sourceComments = CommentThreadCubit(engagement, sessions: manager)
      ..load(targetType: OverthinkingFeedCubit.targetType, targetId: postId);
    comments = sourceComments;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: sourcePosts),
            BlocProvider.value(value: sourceComments),
          ],
          child: OverthinkingDetailScreen(
            post: source,
            revealRequesting: false,
          ),
        ),
      ),
    );
  } catch (_) {
    if (context.mounted && current()) {
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: const Text('Yazı açılamadı. Yeniden deneyebilirsin.'),
        ),
      );
    }
  } finally {
    await comments?.close();
    await posts?.close();
    session.dispose();
    _openingSource[route] = false;
  }
}
