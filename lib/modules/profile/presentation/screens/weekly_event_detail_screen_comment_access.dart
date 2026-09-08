part of 'weekly_event_detail_screen.dart';

class _EventCommentGuestPrompt extends StatelessWidget {
  const _EventCommentGuestPrompt({this.onLogin, this.onRegister});

  final VoidCallback? onLogin;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const BrandGradientIcon.social(Icons.mode_comment_outlined, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Yorum yapmak için giriş yap veya üye ol.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final login = OutlinedButton(
            key: const Key('event-comment-login'),
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(0, 48),
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Giriş Yap'),
          );
          final register = ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: GradientOutlineButton(
              key: const Key('event-comment-register'),
              label: 'Üye Ol',
              onPressed: onRegister,
              backgroundColor: AppColors.inputFill,
              horizontalPadding: 12,
              strokeWidth: .7,
            ),
          );
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(13) > 18) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [login, const SizedBox(height: 8), register],
            );
          }
          return Row(
            children: [
              Expanded(child: login),
              const SizedBox(width: 10),
              Expanded(child: register),
            ],
          );
        },
      ),
    ],
  );
}

// The route owns the controller until its exit animation is complete. A null
// route result (back, drag, barrier, cancel) must never create a reply.
class _EventReplyComposer extends StatefulWidget {
  const _EventReplyComposer({required this.canSubmit});
  final bool Function() canSubmit;

  @override
  State<_EventReplyComposer> createState() => _EventReplyComposerState();
}

class _EventReplyComposerState extends State<_EventReplyComposer> {
  final _controller = TextEditingController();
  bool _finished = false;

  void _submit() {
    final text = _controller.text.trim();
    if (_finished || text.isEmpty || !widget.canSubmit()) return;
    _finished = true;
    Navigator.of(context).pop(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      14,
      18,
      14,
      MediaQuery.viewInsetsOf(context).bottom + 14,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Yanıt yaz',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('event-reply-input'),
          controller: _controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Yanıtını yaz...',
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GradientOutlineButton(
          key: const Key('event-reply-submit'),
          label: 'Gönder',
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          backgroundColor: AppColors.inputFill,
          strokeWidth: .7,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
      ],
    ),
  );
}
