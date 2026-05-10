import 'package:anycast_scout_gui/src/app/localization/app_strings.dart';
import 'package:anycast_scout_gui/src/app/window_manager_bootstrap.dart';
import 'package:anycast_scout_gui/src/features/probe_session/application/dashboard_controller.dart';
import 'package:anycast_scout_gui/src/features/probe_session/application/workflow_mutations.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/dashboard_state.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/presentation/dashboard_section.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/presentation/dashboard_views.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/presentation/status_summary.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/presentation/settings_view.dart';
import 'package:anycast_scout_gui/src/shared/config/ui_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:window_manager/window_manager.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    required this.selected,
    required this.state,
    required this.strings,
    super.key,
  });

  final DashboardSection selected;
  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopHeader(strings: strings),
        _DashboardErrorBanner(error: state.activeError, strings: strings),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: colors.surface,
                  child: _SelectedView(selected, state, strings),
                ),
              ),
              _WorkflowFooter(
                selected: selected,
                state: state,
                strings: strings,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardErrorBanner extends ConsumerWidget {
  const _DashboardErrorBanner({required this.error, required this.strings});

  final DashboardError? error;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = this.error;
    if (error == null) {
      return const SizedBox.shrink();
    }

    final colors = context.appPalette;
    final textTheme = Theme.of(context).textTheme;
    final details = error.details?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorSoft,
        border: Border(
          top: BorderSide(color: colors.error.withValues(alpha: 0.25)),
          bottom: BorderSide(color: colors.error.withValues(alpha: 0.25)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FaIcon(
                FontAwesomeIcons.triangleExclamation,
                size: AppSizes.compactIcon,
                color: colors.error,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    error.message,
                    maxLines: details == null || details.isEmpty ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: colors.text),
                  ),
                  if (details != null && details.isNotEmpty)
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: strings.dismissError,
              onPressed: () =>
                  ref.read(dashboardProvider.notifier).clearError(),
              icon: const FaIcon(
                FontAwesomeIcons.xmark,
                size: AppSizes.compactIcon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindowManagerReady) {
      return _TopHeaderFallback(strings: strings);
    }
    if (shouldUseWindowCaptionButtons) {
      return _TopHeaderWindowButtons(strings: strings);
    }
    return _TopHeaderMacosLike(strings: strings);
  }
}

class _TopHeaderFallback extends StatelessWidget {
  const _TopHeaderFallback({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: SizedBox(
        height: kWindowCaptionHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Center(child: _WindowTitleLine(title: strings.windowTitle)),
        ),
      ),
    );
  }
}

class _TopHeaderWindowButtons extends StatelessWidget {
  const _TopHeaderWindowButtons({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final title = _WindowTitleLine(title: strings.windowTitle);

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: SizedBox(
        height: kWindowCaptionHeight,
        child: WindowCaption(
          backgroundColor: Colors.transparent,
          brightness: Theme.of(context).brightness,
          title: title,
        ),
      ),
    );
  }
}

class _TopHeaderMacosLike extends HookWidget {
  const _TopHeaderMacosLike({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final isMaximized = useState(false);
    final refreshWindowState = useCallback(() async {
      isMaximized.value = await windowManager.isMaximized();
    }, [isMaximized]);

    useEffect(() {
      var disposed = false;

      Future<void> refreshIfMounted() async {
        final nextIsMaximized = await windowManager.isMaximized();
        if (!disposed) {
          isMaximized.value = nextIsMaximized;
        }
      }

      final listener = _WindowMaximizedListener(refreshIfMounted);
      windowManager.addListener(listener);
      refreshIfMounted();

      return () {
        disposed = true;
        windowManager.removeListener(listener);
      };
    }, [isMaximized]);

    final controls = Padding(
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: _MacosWindowButtons(
        isMaximized: isMaximized.value,
        onRefreshState: refreshWindowState,
        strings: strings,
      ),
    );

    final title = _WindowTitleLine(title: strings.windowTitle);

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: SizedBox(
        height: kWindowCaptionHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: DragToMoveArea(child: const SizedBox())),
            Align(alignment: Alignment.center, child: title),
            Align(alignment: Alignment.centerLeft, child: controls),
          ],
        ),
      ),
    );
  }
}

class _WindowMaximizedListener with WindowListener {
  const _WindowMaximizedListener(this.onChanged);

  final Future<void> Function() onChanged;

  @override
  void onWindowMaximize() {
    onChanged();
  }

  @override
  void onWindowUnmaximize() {
    onChanged();
  }
}

class _MacosWindowButtons extends HookWidget {
  const _MacosWindowButtons({
    required this.isMaximized,
    required this.onRefreshState,
    required this.strings,
  });

  final bool isMaximized;
  final Future<void> Function() onRefreshState;
  final AppStrings strings;

  Future<void> _handleAction(Future<void> Function() action) async {
    await action();
    await onRefreshState();
  }

  @override
  Widget build(BuildContext context) {
    final showSymbols = useState(false);

    return MouseRegion(
      onEnter: (_) => showSymbols.value = true,
      onExit: (_) => showSymbols.value = false,
      child: Row(
        children: [
          _MacosWindowButton(
            onTap: () => _handleAction(windowManager.close),
            color: const Color(0xFFFF5F57),
            glyphColor: const Color(0xFF7A1D18),
            glyph: _MacosWindowButtonGlyph.close,
            showSymbol: showSymbols.value,
          ),
          const SizedBox(width: 8),
          _MacosWindowButton(
            onTap: () => _handleAction(windowManager.minimize),
            color: const Color(0xFFFFBD2E),
            glyphColor: const Color(0xFF995700),
            glyph: _MacosWindowButtonGlyph.minimize,
            showSymbol: showSymbols.value,
          ),
          const SizedBox(width: 8),
          _MacosWindowButton(
            onTap: () => _handleAction(
              () => isMaximized
                  ? windowManager.unmaximize()
                  : windowManager.maximize(),
            ),
            color: const Color(0xFF28C840),
            glyphColor: const Color(0xFF0B6F1F),
            glyph: isMaximized
                ? _MacosWindowButtonGlyph.restore
                : _MacosWindowButtonGlyph.zoom,
            showSymbol: showSymbols.value,
          ),
        ],
      ),
    );
  }
}

class _MacosWindowButton extends StatelessWidget {
  const _MacosWindowButton({
    required this.onTap,
    required this.color,
    required this.glyphColor,
    required this.glyph,
    required this.showSymbol,
  });

  final VoidCallback onTap;
  final Color color;
  final Color glyphColor;
  final _MacosWindowButtonGlyph glyph;
  final bool showSymbol;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: kWindowCaptionHeight,
      child: Center(
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.10),
                  width: 0.5,
                ),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 70),
                opacity: showSymbol ? 1 : 0,
                child: CustomPaint(
                  painter: _MacosWindowButtonGlyphPainter(
                    glyph: glyph,
                    color: glyphColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _MacosWindowButtonGlyph { close, minimize, zoom, restore }

class _MacosWindowButtonGlyphPainter extends CustomPainter {
  const _MacosWindowButtonGlyphPainter({
    required this.glyph,
    required this.color,
  });

  final _MacosWindowButtonGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final inset = size.width * 0.32;
    final centerY = size.height / 2;

    switch (glyph) {
      case _MacosWindowButtonGlyph.close:
        canvas
          ..drawLine(
            Offset(inset, inset),
            Offset(size.width - inset, size.height - inset),
            paint,
          )
          ..drawLine(
            Offset(size.width - inset, inset),
            Offset(inset, size.height - inset),
            paint,
          );
      case _MacosWindowButtonGlyph.minimize:
        canvas.drawLine(
          Offset(inset, centerY),
          Offset(size.width - inset, centerY),
          paint,
        );
      case _MacosWindowButtonGlyph.zoom:
        final fill = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas
          ..drawPath(
            Path()
              ..moveTo(size.width * 0.34, size.height * 0.28)
              ..lineTo(size.width * 0.34, size.height * 0.52)
              ..lineTo(size.width * 0.58, size.height * 0.28)
              ..close(),
            fill,
          )
          ..drawPath(
            Path()
              ..moveTo(size.width * 0.66, size.height * 0.72)
              ..lineTo(size.width * 0.66, size.height * 0.48)
              ..lineTo(size.width * 0.42, size.height * 0.72)
              ..close(),
            fill,
          );
      case _MacosWindowButtonGlyph.restore:
        canvas
          ..drawLine(
            Offset(size.width * 0.36, size.height * 0.34),
            Offset(size.width * 0.36, size.height * 0.58),
            paint,
          )
          ..drawLine(
            Offset(size.width * 0.36, size.height * 0.34),
            Offset(size.width * 0.60, size.height * 0.34),
            paint,
          )
          ..drawLine(
            Offset(size.width * 0.64, size.height * 0.66),
            Offset(size.width * 0.64, size.height * 0.42),
            paint,
          )
          ..drawLine(
            Offset(size.width * 0.64, size.height * 0.66),
            Offset(size.width * 0.40, size.height * 0.66),
            paint,
          );
    }
  }

  @override
  bool shouldRepaint(_MacosWindowButtonGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph || oldDelegate.color != color;
  }
}

class _WindowTitleLine extends StatelessWidget {
  const _WindowTitleLine({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.titleSmall?.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w300,
      height: 1.0,
      overflow: TextOverflow.ellipsis,
    );
    final suffixStyle = titleStyle?.copyWith(color: colors.textSubtle);
    const byPingle = ' by Pingle';
    final hasSuffix = title.endsWith(byPingle);
    final primaryTitle = hasSuffix
        ? title.substring(0, title.length - byPingle.length)
        : title;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: kWindowCaptionHeight),
      child: Align(
        alignment: Alignment.center,
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(text: primaryTitle, style: titleStyle),
              if (hasSuffix) TextSpan(text: byPingle, style: suffixStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedView extends ConsumerWidget {
  const _SelectedView(this.selected, this.state, this.strings);

  final DashboardSection selected;
  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget body;

    switch (selected) {
      case DashboardSection.dashboard:
        body = DashboardResultsView(state: state, strings: strings);
      case DashboardSection.journal:
        body = JournalView(state: state, strings: strings);
      case DashboardSection.sessions:
        body = SessionsView(state: state, strings: strings);
      case DashboardSection.settings:
        body = SettingsView(state: state, strings: strings);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: body)],
    );
  }
}

class _WorkflowFooter extends ConsumerWidget {
  const _WorkflowFooter({
    required this.selected,
    required this.state,
    required this.strings,
  });

  final DashboardSection selected;
  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appPalette;
    final clearCandidatesState = ref.watch(clearCandidateChecksMutation);
    final timeoutFallbackState = ref.watch(continueTimeoutFallbackMutation);
    final stopState = ref.watch(stopWorkflowMutation);
    final csvState = ref.watch(openUsableCsvMutation);
    final filesState = ref.watch(revealArtifactsMutation);
    final refreshState = ref.watch(refreshSessionsMutation);
    final clearCandidatesPending = clearCandidatesState is MutationPending;
    final timeoutFallbackPending = timeoutFallbackState is MutationPending;
    final stopPending = stopState is MutationPending;
    final refreshPending = refreshState is MutationPending;

    return Container(
      height: AppSizes.workflowBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          _FooterNavButton(
            icon: FontAwesomeIcons.chartSimple,
            tooltip: strings.dashboard,
            selected: selected == DashboardSection.dashboard,
            onPressed: () => _select(ref, DashboardSection.dashboard),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FooterNavButton(
            icon: FontAwesomeIcons.terminal,
            tooltip: strings.journal,
            selected: selected == DashboardSection.journal,
            onPressed: () => _select(ref, DashboardSection.journal),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FooterNavButton(
            icon: FontAwesomeIcons.boxArchive,
            tooltip: strings.sessions,
            selected: selected == DashboardSection.sessions,
            onPressed: () => _select(ref, DashboardSection.sessions),
          ),
          const Spacer(),
          _StartSplitButton(state: state, strings: strings),
          const SizedBox(width: AppSpacing.sm),
          _ClearCandidateChecksButton(
            state: state,
            strings: strings,
            pending: clearCandidatesPending,
          ),
          const SizedBox(width: AppSpacing.sm),
          _TimeoutFallbackButton(
            state: state,
            strings: strings,
            pending: timeoutFallbackPending,
          ),
          const SizedBox(width: AppSpacing.sm),
          _WorkflowIconButton(
            icon: FontAwesomeIcons.stop,
            tooltip: state.stopping || stopPending
                ? strings.stopping
                : strings.stop,
            onPressed: !state.running || stopPending
                ? null
                : () {
                    stopWorkflowMutation.run(ref, (tsx) async {
                      tsx.get(dashboardProvider.notifier).stopWorkflow();
                    });
                  },
          ),
          const SizedBox(width: AppSpacing.md),
          const _ToolbarDivider(),
          const SizedBox(width: AppSpacing.md),
          _WorkflowIconButton(
            icon: FontAwesomeIcons.fileCsv,
            tooltip: strings.usableCsv,
            onPressed: csvState is MutationPending
                ? null
                : () {
                    openUsableCsvMutation.run(ref, (tsx) async {
                      await tsx.get(dashboardProvider.notifier).openUsableCsv();
                    });
                  },
          ),
          const SizedBox(width: AppSpacing.sm),
          _WorkflowIconButton(
            icon: FontAwesomeIcons.folderOpen,
            tooltip: strings.files,
            onPressed: filesState is MutationPending
                ? null
                : () {
                    revealArtifactsMutation.run(ref, (tsx) async {
                      await tsx
                          .get(dashboardProvider.notifier)
                          .revealSessionFolder();
                    });
                  },
          ),
          if (selected == DashboardSection.sessions) ...[
            const SizedBox(width: AppSpacing.sm),
            _WorkflowIconButton(
              icon: FontAwesomeIcons.arrowsRotate,
              tooltip: strings.refreshSessions,
              onPressed: refreshPending
                  ? null
                  : () {
                      refreshSessionsMutation.run(ref, (tsx) async {
                        await tsx
                            .get(dashboardProvider.notifier)
                            .refreshSessions();
                      });
                    },
              progress: refreshPending,
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          StatusSummaryMenu(state: state, strings: strings),
          const SizedBox(width: AppSpacing.sm),
          _FooterNavButton(
            icon: FontAwesomeIcons.sliders,
            tooltip: strings.settings,
            selected: selected == DashboardSection.settings,
            onPressed: () => _select(ref, DashboardSection.settings),
          ),
        ],
      ),
    );
  }

  void _select(WidgetRef ref, DashboardSection section) {
    ref.read(dashboardSectionProvider.notifier).select(section);
  }
}

class _FooterNavButton extends StatelessWidget {
  const _FooterNavButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final FaIconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _WorkflowIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      primary: selected,
    );
  }
}

class _ClearCandidateChecksButton extends ConsumerWidget {
  const _ClearCandidateChecksButton({
    required this.state,
    required this.strings,
    required this.pending,
  });

  final DashboardState state;
  final AppStrings strings;
  final bool pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRun =
        !state.running &&
        (state.metricInt('usable_count') > 0 ||
            state.metricInt('urltest_count') > 0 ||
            state.urltestResults.isNotEmpty ||
            state.usableResults.isNotEmpty);
    return _WorkflowIconButton(
      icon: FontAwesomeIcons.broom,
      tooltip: strings.clearCandidateChecks,
      onPressed: !canRun || pending
          ? null
          : () {
              clearCandidateChecksMutation.run(ref, (tsx) async {
                await tsx
                    .get(dashboardProvider.notifier)
                    .clearCandidateChecks();
              });
            },
      progress: pending,
    );
  }
}

class _TimeoutFallbackButton extends ConsumerWidget {
  const _TimeoutFallbackButton({
    required this.state,
    required this.strings,
    required this.pending,
  });

  final DashboardState state;
  final AppStrings strings;
  final bool pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRun =
        !state.running &&
        state.metricInt('scanned_count') > 0 &&
        state.text('sing_box_config').trim().isNotEmpty;
    return _WorkflowIconButton(
      icon: FontAwesomeIcons.route,
      tooltip: strings.continueTimeoutFallback,
      onPressed: !canRun || pending
          ? null
          : () {
              continueTimeoutFallbackMutation.run(ref, (tsx) async {
                await tsx
                    .get(dashboardProvider.notifier)
                    .continueTimeoutFallback();
              });
            },
      progress: pending,
    );
  }
}

class _StartSplitButton extends ConsumerWidget {
  const _StartSplitButton({required this.state, required this.strings});

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startPending = ref.watch(startWorkflowMutation) is MutationPending;
    final disabled = state.running || startPending;

    return _WorkflowIconButton(
      icon: FontAwesomeIcons.play,
      tooltip: strings.start,
      onPressed: disabled ? null : () => _runPrimary(ref),
      progress: startPending,
      primary: true,
    );
  }

  void _runPrimary(WidgetRef ref) {
    startWorkflowMutation.run(ref, (tsx) async {
      await tsx.get(dashboardProvider.notifier).startWorkflow();
    });
  }
}

class _WorkflowIconButton extends StatelessWidget {
  const _WorkflowIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
    this.progress = false,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool primary;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    final style = IconButton.styleFrom(
      fixedSize: const Size.square(AppSizes.navButtonHeight),
      minimumSize: const Size.square(AppSizes.navButtonHeight),
      maximumSize: const Size.square(AppSizes.navButtonHeight),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      visualDensity: VisualDensity.compact,
    );
    final iconWidget = progress
        ? SizedBox.square(
            dimension: AppSizes.compactIcon,
            child: CircularProgressIndicator(
              color: primary ? Theme.of(context).colorScheme.onPrimary : null,
              strokeWidth: 2,
            ),
          )
        : FaIcon(icon, size: AppSizes.compactIcon);

    final button = primary
        ? IconButton.filled(
            tooltip: tooltip,
            onPressed: onPressed,
            style: style,
            icon: iconWidget,
          )
        : IconButton.filledTonal(
            tooltip: tooltip,
            onPressed: onPressed,
            style: style,
            icon: iconWidget,
          );

    return button;
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    return SizedBox(
      width: 1,
      height: AppSizes.navButtonHeight,
      child: ColoredBox(color: colors.border),
    );
  }
}
