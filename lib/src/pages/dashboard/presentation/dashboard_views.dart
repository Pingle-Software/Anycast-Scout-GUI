import 'package:anycast_scout_gui/src/app/localization/app_strings.dart';
import 'package:anycast_scout_gui/src/entities/probe_result/usable_ip_result.dart';
import 'package:anycast_scout_gui/src/features/probe_session/application/dashboard_controller.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/dashboard_state.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/probe_artifact_matrix.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/session_summary.dart';
import 'package:anycast_scout_gui/src/pages/dashboard/presentation/status_summary.dart';
import 'package:anycast_scout_gui/src/shared/config/ui_tokens.dart';
import 'package:anycast_scout_gui/src/shared/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

String _formatCompactCount(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    final remaining = raw.length - index;
    buffer.write(raw[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

class DashboardResultsView extends HookWidget {
  const DashboardResultsView({
    required this.state,
    required this.strings,
    super.key,
  });

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final results = useMemoized(
      () => UsableIpResult.rankedFromRows(state.usableResults),
      [state.usableResults],
    );
    final matrix = ProbeArtifactMatrix.fromMetrics(state.metrics);
    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (matrix.hasData)
            _ArtifactMatrixStrip(matrix: matrix, strings: strings),
          if (results.isNotEmpty)
            _ResultsHeader(
              count: results.length,
              state: state,
              strings: strings,
            ),
          Expanded(
            child: results.isEmpty
                ? _EmptyScanState(state: state, strings: strings)
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: results.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return _ResultCard(
                        result: results[index],
                        strings: strings,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyScanState extends StatelessWidget {
  const _EmptyScanState({required this.state, required this.strings});

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final hasScanState =
        state.running ||
        state.metricInt('target_count') > 0 ||
        state.logs.isNotEmpty ||
        state.status != 'Ready';
    final message = dashboardStatusMessage(state, strings);
    final targets = state.metricInt('target_count');
    final showMetrics = targets > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 36,
              color: colors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasScanState ? message.title : strings.noUsableIpsYet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasScanState ? message.body : strings.awaitingExecution,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
            if (showMetrics) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.center,
                children: [
                  if (targets > 0)
                    _StatusMetricChip(
                      label: strings.targetIpsLabel.replaceAll(':', ''),
                      value: _formatCompactCount(targets),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArtifactMatrixStrip extends StatelessWidget {
  const _ArtifactMatrixStrip({required this.matrix, required this.strings});

  final ProbeArtifactMatrix matrix;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.muted,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            _StatusMetricChip(
              label: strings.metricsTargets,
              value: _formatCompactCount(matrix.targets),
            ),
            _StatusMetricChip(
              label: strings.metricsScanned,
              value: _formatCompactCount(matrix.scanned),
            ),
            _StatusMetricChip(
              label: strings.metricsCandidates,
              value: _formatCompactCount(matrix.candidates),
            ),
            _StatusMetricChip(
              label: strings.metricsTested,
              value: _formatCompactCount(matrix.tested),
            ),
            _StatusMetricChip(
              label: strings.metricsUsable,
              value: _formatCompactCount(matrix.verified),
            ),
            _StatusMetricChip(
              label: strings.metricsPending,
              value: _formatCompactCount(matrix.pending),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMetricChip extends StatelessWidget {
  const _StatusMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.muted,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSubtle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: value,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.state,
    required this.strings,
  });

  final int count;
  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final textTheme = Theme.of(context).textTheme;
    final status = dashboardStatusMessage(state, strings);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.plugCircleCheck,
              size: AppSizes.compactIcon,
              color: colors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                strings.usableIps,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: colors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusMetricChip(
              label: strings.verified,
              value: _formatCompactCount(count),
            ),
            if (state.running) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: _StatusMetricChip(
                  label: strings.status,
                  value: status.title,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.strings});

  final UsableIpResult result;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final textTheme = Theme.of(context).textTheme;
    final body = textTheme.bodySmall?.copyWith(
      color: colors.text,
      fontSize: 12,
    );
    final technical = GoogleFonts.tektur(
      color: colors.text,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.3,
      letterSpacing: 0,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        result.ip,
                        maxLines: 1,
                        style: technical.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        result.prefix,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body?.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _RatingBadge(rating: result.rating, strings: strings),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _InfoPill(
                  label: strings.latency,
                  value: formatMs(result.latencyMs),
                ),
                _InfoPill(
                  label: strings.speed,
                  value: formatMbps(result.speedMbps),
                ),
                _InfoPill(
                  label: strings.delay,
                  value: formatMs(result.delayMs),
                ),
                _InfoPill(
                  label: strings.download,
                  value: formatBytes(result.downloadBytes),
                ),
                _InfoPill(label: strings.asn, value: result.asn),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating, required this.strings});

  final double rating;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primarySoft,
        border: Border.all(color: colors.primary.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: SizedBox(
        width: 78,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                strings.rating,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.primaryDark,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${formatRating(rating)}/10',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: colors.primaryDark,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JournalView extends StatelessWidget {
  const JournalView({required this.state, required this.strings, super.key});

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    return state.logs.isEmpty
        ? Center(
            child: Text(
              strings.noTerminalOutput,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.logs.length,
            itemBuilder: (context, index) => SelectableText(
              state.logs[index],
              style: GoogleFonts.tektur(
                color: colors.text,
                fontSize: 11,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          );
  }
}

class SessionsView extends ConsumerWidget {
  const SessionsView({required this.state, required this.strings, super.key});

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appPalette;
    return state.sessions.isEmpty
        ? Center(
            child: Text(
              strings.noSavedSessions,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.sessions.length,
            itemBuilder: (context, index) => _SessionListTile(
              summary: state.sessions[index],
              state: state,
              strings: strings,
            ),
          );
  }
}

class _SessionListTile extends ConsumerWidget {
  const _SessionListTile({
    required this.summary,
    required this.state,
    required this.strings,
  });

  final SessionSummary summary;
  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appPalette;
    final technical = GoogleFonts.tektur(
      color: colors.text,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FaIcon(
                FontAwesomeIcons.fileCode,
                size: AppSizes.iconGlyph,
                color: colors.textSubtle,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  summary.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: technical,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SessionIconButton(
                icon: FontAwesomeIcons.plugCircleCheck,
                tooltip: strings.checkCandidates,
                onPressed: state.running || summary.pendingCandidateChecks == 0
                    ? null
                    : () async {
                        await ref
                            .read(dashboardProvider.notifier)
                            .checkCandidatesFromPath(summary.path);
                      },
              ),
              const SizedBox(width: AppSpacing.xs),
              _SessionIconButton(
                icon: FontAwesomeIcons.play,
                tooltip: strings.continueSessionAction,
                onPressed: state.running
                    ? null
                    : () async {
                        await ref
                            .read(dashboardProvider.notifier)
                            .continueSessionFromPath(summary.path);
                      },
              ),
              const SizedBox(width: AppSpacing.xs),
              _SessionIconButton(
                icon: FontAwesomeIcons.folderOpen,
                tooltip: strings.revealAction,
                onPressed: () async {
                  await ref
                      .read(dashboardProvider.notifier)
                      .revealSessionFile(summary.path);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SessionMetricText(
                label: 'Scanned',
                value: _formatCompactCount(summary.scanResults),
              ),
              _SessionMetricText(
                label: 'Candidates',
                value: _formatCompactCount(summary.scanValid),
              ),
              _SessionMetricText(
                label: 'Verified',
                value: _formatCompactCount(summary.usable),
              ),
              _SessionMetricText(
                label: 'Date',
                value: _formatSavedAt(summary.savedAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionIconButton extends StatelessWidget {
  const _SessionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final FaIconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

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

    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: style,
      icon: FaIcon(icon, size: AppSizes.compactIcon),
    );
  }
}

class _SessionMetricText extends StatelessWidget {
  const _SessionMetricText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.textSubtle,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final valueStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: ', style: labelStyle),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.textSubtle,
      fontWeight: FontWeight.w700,
    );
    final valueStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.muted,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSavedAt(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final local = value.toLocal();
  return '${local.year}-${_pad2(local.month)}-${_pad2(local.day)} '
      '${_pad2(local.hour)}:${_pad2(local.minute)}';
}

String _pad2(int value) => value.toString().padLeft(2, '0');
