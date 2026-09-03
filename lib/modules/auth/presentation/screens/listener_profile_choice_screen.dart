import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../profile/domain/entities/listener_visibility_mode.dart';
import '../../../profile/presentation/cubit/listener_profile_cubit.dart';
import '../../../profile/presentation/cubit/listener_profile_state.dart';
import '../../../profile/presentation/listener_visibility_error_message.dart';
import '../../../profile/presentation/screens/listener_profile_theme.dart';

typedef ListenerProfileChoiceCubitFactory = ListenerProfileCubit Function();
typedef ListenerProfileChoiceCompletion = Future<bool> Function();
typedef ListenerProfileChoiceLogout = Future<void> Function();

class ListenerProfileChoiceScreen extends StatelessWidget {
  const ListenerProfileChoiceScreen({
    super.key,
    this.cubitFactory,
    this.choiceCompletion,
    this.logout,
  });

  final ListenerProfileChoiceCubitFactory? cubitFactory;
  final ListenerProfileChoiceCompletion? choiceCompletion;
  final ListenerProfileChoiceLogout? logout;

  @override
  Widget build(BuildContext context) {
    final completeChoice = choiceCompletion ?? _sessionChoiceCompletion();
    final performLogout = logout ?? _sessionLogout();
    return ListenerProfileTheme(
      child: BlocProvider<ListenerProfileCubit>(
        create: (_) =>
            (cubitFactory?.call() ?? serviceLocator<ListenerProfileCubit>())
              ..loadMyProfile(),
        child: _ListenerProfileChoiceView(
          completeChoice: completeChoice,
          logout: performLogout,
        ),
      ),
    );
  }

  ListenerProfileChoiceCompletion _sessionChoiceCompletion() {
    final sessionManager = serviceLocator<AuthSessionManager>();
    final expectedUserId = sessionManager.session.userId;
    final expectedToken = sessionManager.session.token;
    return () => sessionManager.completeListenerProfileChoice(
      expectedUserId: expectedUserId,
      expectedToken: expectedToken,
    );
  }

  ListenerProfileChoiceLogout _sessionLogout() {
    final sessionManager = serviceLocator<AuthSessionManager>();
    return sessionManager.logout;
  }
}

class _ListenerProfileChoiceView extends StatefulWidget {
  const _ListenerProfileChoiceView({
    required this.completeChoice,
    required this.logout,
  });

  final ListenerProfileChoiceCompletion completeChoice;
  final ListenerProfileChoiceLogout logout;

  @override
  State<_ListenerProfileChoiceView> createState() =>
      _ListenerProfileChoiceViewState();
}

class _ListenerProfileChoiceViewState
    extends State<_ListenerProfileChoiceView> {
  ListenerVisibilityMode? _pendingChoice;
  bool _navigationScheduled = false;
  bool _loggingOut = false;
  bool _recoveringUnexpectedResponse = false;

  @override
  Widget build(BuildContext context) {
    final compactAccountSwitch =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.5;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: BlocConsumer<ListenerProfileCubit, ListenerProfileState>(
                listenWhen: (previous, current) =>
                    previous.status != current.status ||
                    previous.action != current.action ||
                    previous.profile?.visibilityMode !=
                        current.profile?.visibilityMode ||
                    previous.profile?.visibilityChoiceCompleted !=
                        current.profile?.visibilityChoiceCompleted,
                listener: _handleState,
                builder: (context, state) {
                  if (state.profile == null) {
                    if (state.status == ListenerProfileStatus.failure) {
                      return _LoadFailure(
                        message: state.error?.message,
                        onRetry: _loggingOut
                            ? null
                            : () => context
                                  .read<ListenerProfileCubit>()
                                  .loadMyProfile(),
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  }

                  final busy =
                      state.status == ListenerProfileStatus.saving ||
                      _loggingOut ||
                      _recoveringUnexpectedResponse;
                  return _ChoiceContent(
                    busy: busy,
                    pendingChoice: _pendingChoice,
                    onSelect: busy ? null : _select,
                  );
                },
              ),
            ),
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 10),
                  child: compactAccountSwitch
                      ? IconButton(
                          key: const Key('listener-choice-account-switch'),
                          onPressed: _loggingOut ? null : _logout,
                          tooltip: 'Hesap Değiştir',
                          icon: _loggingOut
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.logout_rounded, size: 20),
                        )
                      : TextButton.icon(
                          key: const Key('listener-choice-account-switch'),
                          onPressed: _loggingOut ? null : _logout,
                          icon: _loggingOut
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Hesap Değiştir'),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleState(BuildContext context, ListenerProfileState state) {
    if (_navigationScheduled) return;
    final requested = _pendingChoice;

    if (state.status == ListenerProfileStatus.failure) {
      if ((requested != null || _recoveringUnexpectedResponse) && mounted) {
        setState(() {
          _pendingChoice = null;
          _recoveringUnexpectedResponse = false;
        });
      }
      if (requested == null &&
          state.action == ListenerProfileAction.load &&
          state.profile == null) {
        return;
      }
      final message = state.action == ListenerProfileAction.updateVisibility
          ? listenerVisibilityErrorMessage(state.error)
          : (state.error?.message.trim().isNotEmpty == true
                ? state.error!.message
                : 'Profil bilgilerin alınamadı. Lütfen tekrar dene.');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final profile = state.profile;
    final recoveredCompletedChoice =
        requested == null &&
        state.status == ListenerProfileStatus.success &&
        state.action == ListenerProfileAction.load &&
        profile?.visibilityChoiceCompleted == true;
    if (_recoveringUnexpectedResponse &&
        requested == null &&
        state.status == ListenerProfileStatus.success &&
        state.action == ListenerProfileAction.load &&
        profile?.visibilityChoiceCompleted != true) {
      setState(() => _recoveringUnexpectedResponse = false);
      return;
    }
    final completedRequestedChoice =
        requested != null &&
        state.status == ListenerProfileStatus.success &&
        state.action == ListenerProfileAction.updateVisibility &&
        profile?.visibilityMode == requested &&
        profile?.visibilityChoiceCompleted == true;
    final unverifiedRequestedChoice =
        requested != null &&
        state.status == ListenerProfileStatus.success &&
        state.action == ListenerProfileAction.updateVisibility &&
        !completedRequestedChoice;
    if (unverifiedRequestedChoice) {
      setState(() {
        _pendingChoice = null;
        _recoveringUnexpectedResponse = true;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Tercihin sunucuda doğrulanamadı. Profil bilgilerini yenileyip tekrar dene.',
            ),
          ),
        );
      unawaited(context.read<ListenerProfileCubit>().loadMyProfile());
      return;
    }
    if (!recoveredCompletedChoice && !completedRequestedChoice) {
      return;
    }

    _navigationScheduled = true;
    unawaited(_completeChoiceAndNavigate(context));
  }

  Future<void> _completeChoiceAndNavigate(BuildContext context) async {
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    try {
      final committed = await widget.completeChoice();
      if (!committed) {
        _handleCompletionFailure(
          'Oturum değişti. Profil tercihini yeniden kontrol et.',
        );
        return;
      }
    } catch (_) {
      _handleCompletionFailure(
        'Tercihin kaydedildi ancak bu cihazda doğrulanamadı. Tekrar dene.',
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !navigator.mounted || route?.isCurrent != true) return;
      navigator.pushNamedAndRemoveUntil<void>(
        AppRoutes.listenerProfile,
        (_) => false,
      );
    });
  }

  void _handleCompletionFailure(String message) {
    if (!mounted) return;
    setState(() {
      _navigationScheduled = false;
      _pendingChoice = null;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _select(ListenerVisibilityMode choice) {
    if (_pendingChoice != null ||
        _navigationScheduled ||
        _loggingOut ||
        _recoveringUnexpectedResponse) {
      return;
    }
    setState(() => _pendingChoice = choice);
    unawaited(context.read<ListenerProfileCubit>().updateVisibility(choice));
  }

  Future<void> _logout() async {
    if (_loggingOut || _navigationScheduled) return;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    setState(() => _loggingOut = true);
    try {
      await widget.logout();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Oturum kapatılamadı. Lütfen tekrar dene.'),
          ),
        );
      return;
    }
    if (!mounted || !navigator.mounted || route?.isCurrent != true) return;
    navigator.pushNamedAndRemoveUntil<void>(AppRoutes.login, (_) => false);
  }
}

class _ChoiceContent extends StatelessWidget {
  static const _goldenRatio = 1.61803398875;

  const _ChoiceContent({
    required this.busy,
    required this.pendingChoice,
    required this.onSelect,
  });

  final bool busy;
  final ListenerVisibilityMode? pendingChoice;
  final ValueChanged<ListenerVisibilityMode>? onSelect;

  @override
  Widget build(BuildContext context) {
    final minimumContentHeight =
        (MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).vertical -
                56)
            .clamp(0.0, double.infinity)
            .toDouble();

    return Stack(
      children: [
        const Positioned(
          left: -96,
          top: 22,
          child: _AmbientGlow(color: Color(0x33F06C86), size: 230),
        ),
        const Positioned(
          right: -110,
          bottom: 18,
          child: _AmbientGlow(color: Color(0x2FC15CE0), size: 260),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minimumContentHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sana uygun profil deneyimini seç. Bu tercihi daha sonra '
                    'Ayarlar’dan değiştirebilirsin.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: listenerProfileMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const cardGap = 12.0;
                      final cardWidth = ((constraints.maxWidth - cardGap) / 2)
                          .clamp(0.0, double.infinity)
                          .toDouble();
                      // A square plus a portrait golden rectangle produces
                      // phi-squared: a deliberately tall, still golden-ratio
                      // silhouette. Landscape windows receive a height cap.
                      final idealCardHeight =
                          cardWidth * _goldenRatio * _goldenRatio;
                      final viewportHeightCap = (minimumContentHeight * 0.68)
                          .clamp(320.0, double.infinity)
                          .toDouble();
                      final cardHeight = idealCardHeight < viewportHeightCap
                          ? idealCardHeight
                          : viewportHeightCap;
                      final cards = Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: cardHeight,
                              ),
                              child: _ProfileChoiceCard(
                                key: const Key('listener-choice-social'),
                                title: 'Sosyal Profil',
                                description: 'Standart SoundConnect deneyimi.',
                                accentColors: const [
                                  Color(0xFFFF7A63),
                                  Color(0xFFEF5F9A),
                                  Color(0xFF9A58F4),
                                ],
                                icon: const _SocialChoiceIcon(),
                                loading:
                                    busy &&
                                    pendingChoice ==
                                        ListenerVisibilityMode.standard,
                                enabled: onSelect != null,
                                onTap: () => onSelect?.call(
                                  ListenerVisibilityMode.standard,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: cardGap),
                          Expanded(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: cardHeight,
                              ),
                              child: _ProfileChoiceCard(
                                key: const Key('listener-choice-ghost'),
                                title: 'Hayalet Profil',
                                description:
                                    'SoundConnect’in bütün özelliklerinden '
                                    'faydalanabilirsin ancak profil içeriğin '
                                    'saklı kalır ve bu moddayken yeni profil '
                                    'içeriği kaydedilmez.',
                                accentColors: const [
                                  Color(0xFFF06C86),
                                  Color(0xFFC15CE0),
                                ],
                                icon: const _GhostChoiceIcon(),
                                loading:
                                    busy &&
                                    pendingChoice ==
                                        ListenerVisibilityMode.ghost,
                                enabled: onSelect != null,
                                onTap: () => onSelect?.call(
                                  ListenerVisibilityMode.ghost,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                      final textScale = MediaQuery.textScalerOf(
                        context,
                      ).scale(1);
                      if (textScale <= 1.3) {
                        return SizedBox(height: cardHeight, child: cards);
                      }
                      return IntrinsicHeight(child: cards);
                    },
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: listenerProfileMuted,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'Seçimin profil görünürlüğünü belirler.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: listenerProfileMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileChoiceCard extends StatelessWidget {
  const _ProfileChoiceCard({
    super.key,
    required this.title,
    required this.description,
    required this.accentColors,
    required this.icon,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final List<Color> accentColors;
  final Widget icon;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title seç',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || loading ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: accentColors,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: accentColors.last.withValues(alpha: 0.18),
                blurRadius: 26,
                spreadRadius: -8,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.25),
            child: Material(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onTap : null,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            alignment: Alignment.center,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accentColors.first.withValues(alpha: 0.20),
                                  accentColors.last.withValues(alpha: 0.08),
                                ],
                              ),
                              border: Border.all(
                                color: accentColors.first.withValues(
                                  alpha: 0.26,
                                ),
                              ),
                            ),
                            child: icon,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: listenerProfileMuted,
                              height: 1.42,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: loading
                          ? SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: accentColors.first,
                              ),
                            )
                          : Icon(
                              Icons.arrow_forward_rounded,
                              size: 19,
                              color: accentColors.first,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostChoiceIcon extends StatelessWidget {
  const _GhostChoiceIcon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ).createShader(bounds),
        child: Image.asset(
          'assets/ghost (1).png',
          key: const Key('listener-choice-ghost-icon'),
          fit: BoxFit.contain,
          semanticLabel: 'Hayalet profil simgesi',
        ),
      ),
    );
  }
}

class _SocialChoiceIcon extends StatelessWidget {
  const _SocialChoiceIcon();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      key: const Key('listener-choice-social-icon'),
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      semanticLabel: 'SoundConnect amblemi',
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 8)],
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final effectiveMessage = message?.trim();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 16),
            Text(
              effectiveMessage == null || effectiveMessage.isEmpty
                  ? 'Profil bilgilerin alınamadı.'
                  : effectiveMessage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
