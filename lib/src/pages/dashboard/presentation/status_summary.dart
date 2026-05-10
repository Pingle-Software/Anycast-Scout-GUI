import 'package:anycast_scout_gui/src/app/localization/app_strings.dart';
import 'package:anycast_scout_gui/src/features/probe_session/application/clock_provider.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/dashboard_state.dart';
import 'package:anycast_scout_gui/src/shared/config/ui_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum StatusStage { idle, discovery, scan, connect, warning, failed }

class DashboardStatusMessage {
  const DashboardStatusMessage({required this.title, required this.body});

  final String title;
  final String body;
}

String statusSummaryText(DashboardState state, AppStrings strings) {
  final rawStatus = state.status.trim();
  if (rawStatus.isEmpty) {
    return state.running ? strings.running : strings.idle;
  }
  return compactStatusText(rawStatus, strings);
}

StatusStage statusStage(DashboardState state) {
  if (state.activeError != null || state.status == 'Failed') {
    return StatusStage.failed;
  }
  final value = state.status.trim();
  if (value.startsWith('warning:')) {
    return StatusStage.warning;
  }
  if (value.startsWith('discovery targets written=') ||
      value.startsWith('discovered targets=')) {
    return StatusStage.discovery;
  }
  if (value.startsWith('sing-box batch')) {
    return StatusStage.connect;
  }
  if (value.startsWith('candidate-connect')) {
    return StatusStage.connect;
  }
  if (value.startsWith('scanned=') || value.startsWith('scan batch')) {
    return StatusStage.scan;
  }
  if (state.running &&
      state.metricInt('target_count') == 0 &&
      state.metricInt('scanned_count') == 0 &&
      state.text('asn_list').trim().isNotEmpty) {
    return StatusStage.discovery;
  }
  if (state.running) {
    return StatusStage.scan;
  }
  return StatusStage.idle;
}

String compactStatusText(String status, AppStrings strings) {
  final value = status.trim();
  if (value.startsWith('scanned=')) {
    return strings.scanRunning;
  }
  if (value.startsWith('scan batch')) {
    return strings.scanRunning;
  }
  if (value.startsWith('discovery targets written=') ||
      value.startsWith('discovered targets=')) {
    return strings.discoveryRunning;
  }
  if (value.startsWith('sing-box batch')) {
    return strings.connectRunning;
  }
  if (value.startsWith('candidate-connect')) {
    return strings.connectRunning;
  }
  if (value.startsWith('warning:')) {
    return strings.warningStatus;
  }
  return value;
}

DashboardStatusMessage dashboardStatusMessage(
  DashboardState state,
  AppStrings strings,
) {
  final stage = statusStage(state);
  final scanned = state.metricInt('scanned_count');
  final valid = state.metricInt('scan_valid_count');
  final targets = state.metricInt('target_count');
  final usable = state.metricInt('usable_count');

  return switch (stage) {
    StatusStage.discovery => DashboardStatusMessage(
      title: strings.discoveryRunning,
      body: targets > 0
          ? strings.discoveryTargetsStatus(_formatCount(targets))
          : '${strings.discoveryStartingStatus}. ${strings.statusInProgress}',
    ),
    StatusStage.scan => DashboardStatusMessage(
      title: strings.scanRunning,
      body: valid > 0
          ? strings.scanningValidStatus(
              _formatCount(valid),
              _formatCount(scanned),
            )
          : scanned > 0
          ? strings.scanningNoValidStatus(_formatCount(scanned))
          : '${strings.scanStartingStatus}. ${strings.statusInProgress}',
    ),
    StatusStage.connect => DashboardStatusMessage(
      title: strings.connectRunning,
      body: strings.connectProgressStatus(
        _formatCount(valid),
        _formatCount(usable),
      ),
    ),
    StatusStage.warning => DashboardStatusMessage(
      title: strings.warningStatus,
      body: strings.warningProgressStatus,
    ),
    StatusStage.failed => DashboardStatusMessage(
      title: strings.failed,
      body: state.activeError?.message ?? strings.warningProgressStatus,
    ),
    StatusStage.idle => DashboardStatusMessage(
      title: state.usableResults.isEmpty
          ? strings.noUsableIpsYet
          : strings.ready,
      body: state.usableResults.isEmpty
          ? strings.awaitingExecution
          : strings.readyForConnection(state.usableResults.length),
    ),
  };
}

class StatusSummary extends ConsumerWidget {
  const StatusSummary({required this.state, required this.strings, super.key});

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final rawStatus = state.status.trim();
    final statusText = statusSummaryText(state, strings);
    final targets = state.metricInt('target_count');
    final valid = state.metricInt('scan_valid_count');
    final elapsed = _elapsedDuration(state, now);
    final estimated = _estimatedRemaining(state, elapsed);
    final rows = <Widget>[
      _StatusMetricTile(
        label: strings.status,
        value: statusText,
        tooltip: rawStatus.isEmpty || rawStatus == statusText
            ? null
            : rawStatus,
      ),
      _StatusMetricTile(
        label: strings.targetIpsLabel.replaceAll(':', ''),
        value: _formatCount(targets),
      ),
      _StatusMetricTile(
        label: strings.validIpsLabel.replaceAll(':', ''),
        value: _formatCount(valid),
      ),
      _StatusMetricTile(
        label: strings.estimatedLabel.replaceAll(':', ''),
        value: _formatCompactDuration(estimated),
      ),
      _StatusMetricTile(
        label: strings.elapsedLabel.replaceAll(':', ''),
        value: _formatCompactDuration(elapsed),
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const _StatusMetricDivider(),
        ],
      ],
    );
  }
}

class StatusSummaryMenu extends ConsumerWidget {
  const StatusSummaryMenu({
    required this.state,
    required this.strings,
    this.labelled = false,
    this.statusText,
    super.key,
  });

  final DashboardState state;
  final AppStrings strings;
  final bool labelled;
  final String? statusText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final label = statusText ?? statusSummaryText(state, strings);
    final menuContent = _StatusMenuPanel(
      state: state,
      strings: strings,
      now: now,
      statusText: label,
    );

    final menu = MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: menuContent,
        ),
      ],
      builder: (context, controller, child) {
        return Tooltip(
          message: strings.status,
          child: _StatusMenuButton(
            labelled: labelled,
            label: label,
            open: controller.isOpen,
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          ),
        );
      },
    );

    if (labelled) {
      return Material(color: Colors.transparent, child: menu);
    }

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: AppSizes.navButtonHeight,
        height: AppSizes.navButtonHeight,
        child: menu,
      ),
    );
  }
}

class _StatusMenuButton extends StatelessWidget {
  const _StatusMenuButton({
    required this.labelled,
    required this.label,
    required this.open,
    required this.onPressed,
  });

  final bool labelled;
  final String label;
  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final foreground = colors.text;
    final border = colors.border;
    final background = colors.muted;

    if (!labelled) {
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

      return SizedBox(
        width: AppSizes.navButtonHeight,
        height: AppSizes.navButtonHeight,
        child: IconButton.filledTonal(
          onPressed: onPressed,
          style: style,
          icon: const FaIcon(
            FontAwesomeIcons.circleInfo,
            size: AppSizes.compactIcon,
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32, maxWidth: 360),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(AppRadii.md),
              color: background,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FaIcon(
                    open
                        ? FontAwesomeIcons.chevronUp
                        : FontAwesomeIcons.chevronDown,
                    size: AppSizes.compactIcon,
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMenuPanel extends StatelessWidget {
  const _StatusMenuPanel({
    required this.state,
    required this.strings,
    required this.now,
    required this.statusText,
  });

  final DashboardState state;
  final AppStrings strings;
  final DateTime now;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final targets = state.metricInt('target_count');
    final valid = state.metricInt('scan_valid_count');
    final elapsed = _elapsedDuration(state, now);
    final estimated = _estimatedRemaining(state, elapsed);
    final rawStatus = state.status.trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 288,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusMetricTile(
                label: strings.status,
                value: statusText,
                tooltip: rawStatus.isEmpty || rawStatus == statusText
                    ? null
                    : rawStatus,
              ),
              const _StatusMetricDivider(),
              _StatusMetricTile(
                label: strings.targetIpsLabel.replaceAll(':', ''),
                value: _formatCount(targets),
              ),
              _StatusMetricTile(
                label: strings.validIpsLabel.replaceAll(':', ''),
                value: _formatCount(valid),
              ),
              _StatusMetricTile(
                label: strings.estimatedLabel.replaceAll(':', ''),
                value: _formatCompactDuration(estimated),
              ),
              _StatusMetricTile(
                label: strings.elapsedLabel.replaceAll(':', ''),
                value: _formatCompactDuration(elapsed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMetricTile extends StatelessWidget {
  const _StatusMetricTile({
    required this.label,
    required this.value,
    this.tooltip,
  });

  final String label;
  final String value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    final valueStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colors.textMuted,
      fontWeight: FontWeight.w700,
    );
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colors.textMuted,
      fontWeight: FontWeight.w600,
    );

    return SizedBox(
      height: 30,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            color: Colors.transparent,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 0,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  child: Text(
                    label,
                    style: labelStyle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatusMetricValue(
                    value: value,
                    style: valueStyle,
                    tooltip: tooltip,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMetricValue extends StatelessWidget {
  const _StatusMetricValue({
    required this.value,
    required this.style,
    this.tooltip,
  });

  final String value;
  final TextStyle? style;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      value,
      style: style,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
    final message = tooltip?.trim();
    if (message == null || message.isEmpty) {
      return child;
    }
    return Tooltip(message: message, child: child);
  }
}

class _StatusMetricDivider extends StatelessWidget {
  const _StatusMetricDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.appPalette;
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.borderStrong.withValues(alpha: 0.65),
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
    );
  }
}

Duration? _elapsedDuration(DashboardState state, DateTime now) {
  final startedAt = state.sessionStartedAt;
  if (startedAt != null) {
    final elapsed = now.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  final elapsedMs = state.metricInt('total_elapsed_ms');
  if (elapsedMs > 0) {
    return Duration(milliseconds: elapsedMs);
  }

  return null;
}

Duration? _estimatedRemaining(DashboardState state, Duration? elapsed) {
  if (!state.running || elapsed == null || elapsed.inSeconds < 3) {
    return null;
  }

  final targets = state.metricInt('target_count');
  final scanned = state.metricInt('scanned_count');
  if (targets <= 0 || scanned <= 0 || scanned >= targets) {
    return null;
  }

  final totalSeconds = elapsed.inSeconds * targets / scanned;
  final remainingSeconds = totalSeconds - elapsed.inSeconds;
  if (!remainingSeconds.isFinite || remainingSeconds <= 0) {
    return null;
  }

  return Duration(seconds: remainingSeconds.round());
}

String _formatCompactDuration(Duration? duration) {
  if (duration == null) {
    return '--:--';
  }

  final seconds = duration.inSeconds;
  if (seconds < 60) {
    return '${seconds}s';
  }

  final minutes = duration.inMinutes;
  if (minutes < 60) {
    return '${minutes}m';
  }

  final hours = duration.inHours;
  final remainderMinutes = minutes.remainder(60);
  if (hours < 24) {
    return remainderMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainderMinutes}m';
  }

  final days = duration.inDays;
  final remainderHours = hours.remainder(24);
  return remainderHours == 0 ? '${days}d' : '${days}d ${remainderHours}h';
}

String _formatCount(int value) {
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
