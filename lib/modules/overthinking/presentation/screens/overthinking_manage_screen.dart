import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/policy/stage_mode.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/ghost_profile_badge.dart';
import '../../../profile/presentation/screens/profile_public_bottom_bar.dart';
import '../../domain/entities/overthinking_post.dart';
import '../../domain/entities/overthinking_reveal_request.dart';
import '../../domain/overthinking_repository.dart';

class OverthinkingManageScreen extends StatefulWidget {
  final StageMode bottomBarStageMode;
  final int initialTabIndex;

  const OverthinkingManageScreen({
    super.key,
    this.bottomBarStageMode = StageMode.mainstage,
    this.initialTabIndex = 0,
  });

  @override
  State<OverthinkingManageScreen> createState() =>
      _OverthinkingManageScreenState();
}

class _OverthinkingManageScreenState extends State<OverthinkingManageScreen> {
  late final OverthinkingRepository _repository =
      serviceLocator<OverthinkingRepository>();

  bool _loadingPosts = true;
  bool _loadingIncoming = true;
  bool _loadingSent = true;
  String? _postsError;
  String? _incomingError;
  String? _sentError;
  List<OverthinkingPost> _posts = const [];
  List<OverthinkingRevealRequest> _incoming = const [];
  List<OverthinkingRevealRequest> _sent = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPosts(), _loadIncoming(), _loadSent()]);
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });
    final result = await _repository.getMyPosts(size: 30);
    if (!mounted) return;
    setState(() {
      _loadingPosts = false;
      if (result.isSuccess && result.data != null) {
        _posts = result.data!.items;
      } else {
        _postsError = result.error?.message ?? 'Paylaşımların getirilemedi';
      }
    });
  }

  Future<void> _loadIncoming() async {
    setState(() {
      _loadingIncoming = true;
      _incomingError = null;
    });
    final result = await _repository.getIncomingRevealRequests(size: 30);
    if (!mounted) return;
    setState(() {
      _loadingIncoming = false;
      if (result.isSuccess && result.data != null) {
        _incoming = result.data!.items;
      } else {
        _incomingError =
            result.error?.message ?? 'Gelen kimlik istekleri getirilemedi';
      }
    });
  }

  Future<void> _loadSent() async {
    setState(() {
      _loadingSent = true;
      _sentError = null;
    });
    final result = await _repository.getSentRevealRequests(size: 30);
    if (!mounted) return;
    setState(() {
      _loadingSent = false;
      if (result.isSuccess && result.data != null) {
        _sent = result.data!.items;
      } else {
        _sentError =
            result.error?.message ?? 'Gönderilen kimlik istekleri getirilemedi';
      }
    });
  }

  Future<void> _openPostPreview(OverthinkingPost post) async {
    final result = await _repository.getDetail(postId: post.id);
    if (!mounted) return;
    final detail = result.data ?? post;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PostPreviewSheet(post: detail),
    );
  }

  Future<void> _editPost(OverthinkingPost post) async {
    final updated = await showModalBottomSheet<OverthinkingPost>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditPostSheet(repository: _repository, post: post),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _posts = _posts
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Paylaşım güncellendi')));
  }

  Future<void> _deletePost(OverthinkingPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paylaşım silinsin mi?'),
        content: Text(post.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _repository.deletePost(postId: post.id);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _posts = _posts.where((item) => item.id != post.id).toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Paylaşım silindi')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error?.message ?? 'Paylaşım silinemedi')),
    );
  }

  Future<void> _decideReveal(
    OverthinkingRevealRequest request,
    bool approve,
  ) async {
    final result = approve
        ? await _repository.approveRevealRequest(requestId: request.id)
        : await _repository.rejectRevealRequest(requestId: request.id);
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() {
        _incoming = _incoming
            .map((item) => item.id == request.id ? result.data! : item)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'İstek kabul edildi' : 'İstek reddedildi'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error?.message ??
              (approve ? 'İstek kabul edilemedi' : 'İstek reddedilemedi'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Overthinking Yönetimi'),
          centerTitle: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Benim Kalemimden'),
              Tab(text: 'Gelen İstekler'),
              Tab(text: 'Giden İstekler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PostListTab(
              loading: _loadingPosts,
              errorText: _postsError,
              posts: _posts,
              onRefresh: _loadPosts,
              onOpen: _openPostPreview,
              onEdit: _editPost,
              onDelete: _deletePost,
            ),
            _RevealListTab(
              loading: _loadingIncoming,
              errorText: _incomingError,
              requests: _incoming,
              onRefresh: _loadIncoming,
              incoming: true,
              onApprove: (request) => _decideReveal(request, true),
              onReject: (request) => _decideReveal(request, false),
            ),
            _RevealListTab(
              loading: _loadingSent,
              errorText: _sentError,
              requests: _sent,
              onRefresh: _loadSent,
              incoming: false,
            ),
          ],
        ),
        bottomNavigationBar: ProfilePublicBottomBar(
          currentIndex: widget.bottomBarStageMode == StageMode.mainstage
              ? 1
              : 2,
          stageMode: widget.bottomBarStageMode,
        ),
      ),
    );
  }
}

class _PostListTab extends StatelessWidget {
  final bool loading;
  final String? errorText;
  final List<OverthinkingPost> posts;
  final Future<void> Function() onRefresh;
  final ValueChanged<OverthinkingPost> onOpen;
  final ValueChanged<OverthinkingPost> onEdit;
  final ValueChanged<OverthinkingPost> onDelete;

  const _PostListTab({
    required this.loading,
    required this.errorText,
    required this.posts,
    required this.onRefresh,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (errorText != null) return _CenteredMessage(text: errorText!);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: posts.isEmpty
          ? const _CenteredMessage(text: 'Henüz paylaşımın yok.')
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final post = posts[index];
                return _PostManageCard(
                  post: post,
                  onOpen: () => onOpen(post),
                  onEdit: () => onEdit(post),
                  onDelete: () => onDelete(post),
                );
              },
            ),
    );
  }
}

class _RevealListTab extends StatelessWidget {
  final bool loading;
  final String? errorText;
  final List<OverthinkingRevealRequest> requests;
  final Future<void> Function() onRefresh;
  final bool incoming;
  final ValueChanged<OverthinkingRevealRequest>? onApprove;
  final ValueChanged<OverthinkingRevealRequest>? onReject;

  const _RevealListTab({
    required this.loading,
    required this.errorText,
    required this.requests,
    required this.onRefresh,
    required this.incoming,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (errorText != null) return _CenteredMessage(text: errorText!);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: requests.isEmpty
          ? _CenteredMessage(
              text: incoming
                  ? 'Henüz gelen kimlik isteği yok.'
                  : 'Gönderdiğin istekler burada görünecek.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = requests[index];
                final pending = request.status == 'PENDING';
                return _RevealRequestCard(
                  request: request,
                  incoming: incoming,
                  footer: incoming && pending
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => onReject?.call(request),
                                child: const Text('Reddet'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => onApprove?.call(request),
                                child: const Text('Kabul et'),
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: _StatusPill(status: request.status),
                        ),
                );
              },
            ),
    );
  }
}

class _PostManageCard extends StatelessWidget {
  final OverthinkingPost post;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostManageCard({
    required this.post,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MusicThumb(post: post),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        post.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _VisibilityPill(post: post),
                const Spacer(),
                IconButton(
                  tooltip: 'Düzenle',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Sil',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealRequestCard extends StatelessWidget {
  final OverthinkingRevealRequest request;
  final bool incoming;
  final Widget footer;

  const _RevealRequestCard({
    required this.request,
    required this.incoming,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            request.postTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          if (incoming)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RevealRequesterAvatar(request: request),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@${request.requesterUsername}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (request.isRequesterGhost) ...[
                            const SizedBox(width: 7),
                            GhostProfileBadge(
                              key: ValueKey<String>(
                                'reveal-requester-ghost-${request.id}',
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bu paylaşımda kimliğini görmek istiyor.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              _statusText(request.status),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          const SizedBox(height: 12),
          footer,
        ],
      ),
    );
  }

  String _statusText(String status) {
    return switch (status) {
      'APPROVED' => 'Kimlik görüntüleme isteğin kabul edildi.',
      'REJECTED' => 'Kimlik görüntüleme isteğin reddedildi.',
      _ => 'Kimlik görüntüleme isteğin beklemede.',
    };
  }
}

class _RevealRequesterAvatar extends StatelessWidget {
  const _RevealRequesterAvatar({required this.request});

  final OverthinkingRevealRequest request;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = request.requesterAvatarUrl?.trim();
    final fallback = request.requesterUsername.trim().isEmpty
        ? '?'
        : request.requesterUsername.trim().characters.first.toUpperCase();

    return Container(
      key: ValueKey<String>('reveal-requester-avatar-${request.id}'),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              fallback,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w900,
              ),
            )
          : Image.network(
              avatarUrl,
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Text(
                fallback,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }
}

class _EditPostSheet extends StatefulWidget {
  final OverthinkingRepository repository;
  final OverthinkingPost post;

  const _EditPostSheet({required this.repository, required this.post});

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final TextEditingController _titleController = TextEditingController(
    text: widget.post.title,
  );
  late final TextEditingController _contentController = TextEditingController(
    text: widget.post.content,
  );
  late bool _anonymous = widget.post.anonymous;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Başlık ve metin zorunlu')));
      return;
    }
    setState(() => _saving = true);
    final result = await widget.repository.updatePost(
      postId: widget.post.id,
      title: title,
      content: content,
      visibilityType: _anonymous ? 'ANONYMOUS' : 'VISIBLE',
      spotifyTrackUrl: widget.post.spotifyTrackUrl,
      spotifyArtistId: widget.post.spotifyArtistId,
      spotifyTrackName: widget.post.spotifyTrackName,
      spotifyArtistName: widget.post.spotifyArtistName,
      spotifyAlbumImageUrl: widget.post.spotifyAlbumImageUrl,
      musicianTrackId: widget.post.musicianTrackId,
      bandTrackId: widget.post.bandTrackId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess && result.data != null) {
      Navigator.of(context).pop(result.data);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.error?.message ?? 'Paylaşım güncellenemedi'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 14),
              Text(
                'Paylaşımı düzenle',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                maxLength: 64,
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                minLines: 5,
                maxLines: 8,
                maxLength: 10240,
                decoration: const InputDecoration(labelText: 'Metin'),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _anonymous,
                onChanged: (value) => setState(() => _anonymous = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Anonim paylaş'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostPreviewSheet extends StatelessWidget {
  final OverthinkingPost post;

  const _PostPreviewSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 14),
            Row(
              children: [
                _MusicThumb(post: post, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _VisibilityPill(post: post),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              post.content,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicThumb extends StatelessWidget {
  final OverthinkingPost post;
  final double size;

  const _MusicThumb({required this.post, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.spotifyAlbumImageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _musicFallback(context),
              )
            : _musicFallback(context),
      ),
    );
  }

  Widget _musicFallback(BuildContext context) {
    return Icon(
      Icons.music_note_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      size: 20,
    );
  }
}

class _VisibilityPill extends StatelessWidget {
  final OverthinkingPost post;

  const _VisibilityPill({required this.post});

  @override
  Widget build(BuildContext context) {
    final label = post.anonymous ? 'Anonim' : 'Görünür';
    final color = post.anonymous ? AppColors.coralAlt : AppColors.spotifyGreen;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final approved = status == 'APPROVED';
    final rejected = status == 'REJECTED';
    final color = approved
        ? Colors.green
        : rejected
        ? Colors.redAccent
        : AppColors.coralAlt;
    final label = approved
        ? 'Kabul edildi'
        : rejected
        ? 'Reddedildi'
        : 'Beklemede';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String text;

  const _CenteredMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Theme.of(context).dividerColor),
  );
}
