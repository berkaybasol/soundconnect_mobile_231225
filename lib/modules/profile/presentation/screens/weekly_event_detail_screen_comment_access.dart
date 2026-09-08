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
  const _EventReplyComposer({
    required this.canSubmit,
    required this.onSubmit,
    required this.errorText,
  });
  final bool Function() canSubmit;
  final Future<bool> Function(String) onSubmit;
  final String? Function() errorText;

  @override
  State<_EventReplyComposer> createState() => _EventReplyComposerState();
}

class _EventReplyComposerState extends State<_EventReplyComposer> {
  final _controller = TextEditingController();
  bool _finished = false;
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (!mounted ||
        _finished ||
        _saving ||
        !widget.canSubmit() ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final text = _controller.text.trim();
    if (!CommentText.isValid(text)) return;
    final route = ModalRoute.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    var sent = false;
    try {
      sent = await widget.onSubmit(text);
    } catch (_) {
      /* The editor retains the draft on an unconfirmed write. */
    }
    if (!mounted) return;
    if (!sent) {
      setState(() {
        _saving = false;
        _error =
            widget.errorText() ??
            'Gönderim doğrulanamadı. Tekrar göndermeden yorumları kontrol et.';
      });
      return;
    }
    _finished = true;
    if (route?.isCurrent == true) {
      Navigator.of(context).pop();
    } else if (route?.isActive == true) {
      route!.navigator?.removeRoute(route);
    }
  }

  void _cancel() {
    if (!mounted ||
        _finished ||
        _saving ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _finished = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SingleChildScrollView(
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
            readOnly: _saving,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Yanıtını yaz...',
              counterText:
                  '${CommentText.length(_controller.text)}/${CommentText.maxLength}',
              errorText:
                  CommentText.length(_controller.text) > CommentText.maxLength
                  ? 'Yanıtını biraz kısalt.'
                  : null,
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
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          GradientOutlineButton(
            key: const Key('event-reply-submit'),
            label: _saving ? 'Gönderiliyor...' : 'Gönder',
            onPressed: _saving || !CommentText.isValid(_controller.text)
                ? null
                : _submit,
            backgroundColor: AppColors.inputFill,
            strokeWidth: .7,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _saving ? null : _cancel,
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    ),
  );
}
