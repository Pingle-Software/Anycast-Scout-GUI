import 'dart:async';

import 'package:anycast_scout_gui/src/app/app_versions.dart' as app_versions;
import 'package:anycast_scout_gui/src/app/localization/app_strings.dart';
import 'package:anycast_scout_gui/src/app/theme/app_theme_preference.dart';
import 'package:anycast_scout_gui/src/app/theme/theme_preference_controller.dart';
import 'package:anycast_scout_gui/src/features/probe_session/application/dashboard_controller.dart';
import 'package:anycast_scout_gui/src/features/probe_session/application/workflow_mutations.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/dashboard_state.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/discovery_profile.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workflow_config.dart';
import 'package:anycast_scout_gui/src/shared/config/ui_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const _settingsControlHeight = AppSizes.controlHeight;

const _settingsDropdownDecoration = InputDecoration(
  isDense: true,
  constraints: BoxConstraints.tightFor(height: _settingsControlHeight),
  contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
);

const _settingsDropdownMenuWidth = 280.0;
const _settingsDropdownPadding = EdgeInsets.symmetric(vertical: 9);

class SettingsView extends StatelessWidget {
  const SettingsView({required this.state, required this.strings, super.key});

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            tabs: [
              Tab(height: 34, text: strings.appearance),
              Tab(height: 34, text: strings.core),
              Tab(height: 34, text: strings.discovery),
              Tab(height: 34, text: strings.validation),
              Tab(height: 34, text: strings.about),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _AppearanceSettings(strings: strings),
                _CoreSettings(state: state, strings: strings),
                _DiscoverySettings(state: state, strings: strings),
                _ValidationSettings(state: state, strings: strings),
                _AboutSettings(strings: strings),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSettings extends ConsumerWidget {
  const _AppearanceSettings({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(appThemePreferenceProvider);
    final controller = ref.read(appThemePreferenceProvider.notifier);

    return _SettingsSections(
      groups: [
        _SettingsGroup(
          icon: FontAwesomeIcons.circleHalfStroke,
          title: strings.appearance,
          description: strings.appearanceDescription,
          sections: [
            _SettingsSubsection(
              children: [
                _SegmentedRow<AppThemePreference>(
                  label: strings.theme,
                  value: preference,
                  values: {
                    AppThemePreference.system: strings.themeSystem,
                    AppThemePreference.light: strings.themeLight,
                    AppThemePreference.dark: strings.themeDark,
                  },
                  tooltips: {
                    AppThemePreference.system: strings.themeSystemHint,
                    AppThemePreference.light: strings.themeLightHint,
                    AppThemePreference.dark: strings.themeDarkHint,
                  },
                  onChanged: (value) =>
                      unawaited(controller.setPreference(value)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CoreSettings extends ConsumerWidget {
  const _CoreSettings({required this.state, required this.strings});

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(dashboardProvider.notifier);
    final pickCoreState = ref.watch(pickCoreBinaryMutation);
    final pickSingBoxState = ref.watch(pickSingBoxConfigMutation);
    final missingConfigPath = localSingBoxConfigMissingWarning(state);
    final outboundTags = localSingBoxOutboundTags(state);
    final selectedOutbound = state.text('outbound_tag');

    return _SettingsSections(
      groups: [
        _SettingsGroup(
          icon: FontAwesomeIcons.folder,
          title: strings.core,
          description: strings.pathsDescription,
          sections: [
            _SettingsSubsection(
              children: [
                _TextRow(
                  label: strings.anycastScoutRustBinary,
                  value: state.coreBinaryPath,
                  enabled: !state.running,
                  trailing: _BrowseButton(
                    pending: pickCoreState is MutationPending,
                    enabled: !state.running,
                    tooltip: strings.browse,
                    onPressed: () {
                      pickCoreBinaryMutation.run(ref, (tsx) async {
                        await tsx
                            .get(dashboardProvider.notifier)
                            .pickCoreBinary();
                      });
                    },
                  ),
                ),
              ],
            ),
            _SettingsSubsection(
              icon: FontAwesomeIcons.boxArchive,
              title: strings.singBoxBinary,
              description: strings.singBoxDescription,
              children: [
                _ConfigTextRow(
                  state: state,
                  controller: controller,
                  label: strings.configPath,
                  configKey: 'sing_box_config',
                  enabled: !state.running,
                  trailing: _BrowseButton(
                    pending: pickSingBoxState is MutationPending,
                    enabled: !state.running,
                    tooltip: strings.browse,
                    onPressed: () {
                      pickSingBoxConfigMutation.run(ref, (tsx) async {
                        await tsx
                            .get(dashboardProvider.notifier)
                            .pickSingBoxConfig();
                      });
                    },
                  ),
                ),
                if (missingConfigPath != null)
                  _InlineWarning(
                    message: strings.singBoxConfigMissing(missingConfigPath),
                  ),
                _DropdownRow<String>(
                  label: strings.outboundTag,
                  value: outboundTags.contains(selectedOutbound)
                      ? selectedOutbound
                      : null,
                  values: outboundTags,
                  emptyValue: selectedOutbound.isEmpty
                      ? strings.noOutboundsInConfig
                      : selectedOutbound,
                  enabled: !state.running && outboundTags.isNotEmpty,
                  onChanged: (value) =>
                      controller.updateChoiceField('outbound_tag', value),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DiscoverySettings extends ConsumerWidget {
  const _DiscoverySettings({required this.state, required this.strings});

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(dashboardProvider.notifier);
    return _SettingsSections(
      groups: [
        _SettingsGroup(
          icon: FontAwesomeIcons.route,
          title: strings.discovery,
          description: strings.discoveryDescription,
          sections: [
            _SettingsSubsection(
              children: [
                _SegmentedRow<DiscoveryProfile>(
                  label: strings.discoveryProfile,
                  value: state.discoveryProfile,
                  values: {
                    DiscoveryProfile.cloudflareCandidates:
                        strings.cloudflareCandidates,
                    DiscoveryProfile.custom: strings.customAsns,
                  },
                  onChanged: state.running
                      ? null
                      : controller.updateDiscoveryProfile,
                ),
                _ConfigTextRow(
                  state: state,
                  controller: controller,
                  label: strings.asnList,
                  configKey: 'asn_list',
                  enabled:
                      !state.running &&
                      state.discoveryProfile == DiscoveryProfile.custom,
                  editable: true,
                ),
                _SegmentedRow<String>(
                  label: strings.scope,
                  value: state.text('discovery_scope'),
                  values: {
                    'Origin': strings.scopeOrigin,
                    'AsPath': strings.scopeAsPath,
                    'OriginAndAsPath': strings.scopeOriginAndAsPath,
                  },
                  tooltips: {
                    'Origin': strings.scopeOriginHint,
                    'AsPath': strings.scopeAsPathHint,
                    'OriginAndAsPath': strings.scopeOriginAndAsPathHint,
                  },
                  onChanged: state.running
                      ? null
                      : (value) => controller.updateChoiceField(
                          'discovery_scope',
                          value,
                        ),
                ),
              ],
            ),
            _SettingsSubsection(
              icon: FontAwesomeIcons.filter,
              title: strings.targeting,
              description: strings.targetingDescription,
              children: [
                _SwitchRow(
                  label: strings.expandAllHosts,
                  value: state.flag('all_hosts'),
                  enabled: !state.running,
                  strings: strings,
                  hint: strings.expandAllHostsHint,
                  onChanged: (value) =>
                      controller.updateBoolField('all_hosts', value),
                ),
                ..._configTextRows(state, controller, [
                  _ConfigTextField(
                    label: strings.maxIps,
                    configKey: 'max_targets',
                    enabled: !state.running,
                    hint: strings.maxIpsHint,
                    editable: true,
                  ),
                ]),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ValidationSettings extends ConsumerWidget {
  const _ValidationSettings({required this.state, required this.strings});

  final DashboardState state;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(dashboardProvider.notifier);
    return _SettingsSections(
      groups: [
        _SettingsGroup(
          icon: FontAwesomeIcons.scaleBalanced,
          title: strings.validation,
          description: strings.validationDescription,
          sections: [
            _SettingsSubsection(
              children: _configTextRows(state, controller, [
                _ConfigTextField(
                  label: strings.scanConcurrency,
                  configKey: 'concurrency',
                  enabled: !state.running,
                  hint: strings.scanConcurrencyHint,
                  editable: true,
                ),
                _ConfigTextField(
                  label: strings.singBoxConcurrency,
                  configKey: 'urltest_concurrency',
                  enabled: !state.running,
                  hint: strings.singBoxConcurrencyHint,
                  editable: true,
                ),
                _ConfigTextField(
                  label: strings.timeoutFallbackBudget,
                  configKey: 'timeout_fallback_budget',
                  enabled: !state.running,
                  hint: strings.timeoutFallbackBudgetHint,
                  editable: true,
                ),
                _ConfigTextField(
                  label: strings.maxUsableResults,
                  configKey: 'max_valid',
                  enabled: !state.running,
                  hint: strings.maxUsableResultsHint,
                  editable: true,
                ),
                _ConfigTextField(
                  label: strings.speedUrl,
                  configKey: 'speed_url',
                  enabled: !state.running,
                  pathAware: false,
                  hint: strings.speedUrlHint,
                  editable: true,
                ),
                _ConfigTextField(
                  label: strings.downloadUrl,
                  configKey: 'download_url',
                  enabled: !state.running,
                  pathAware: false,
                  hint: strings.downloadUrlHint,
                  editable: true,
                ),
                _ConfigTextField(
                  label: strings.minDownloadBytes,
                  configKey: 'min_download_bytes',
                  enabled: !state.running,
                  hint: strings.minDownloadBytesHint,
                  editable: true,
                ),
              ]),
            ),
          ],
        ),
      ],
    );
  }
}

class _AboutSettings extends StatelessWidget {
  const _AboutSettings({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return _SettingsSections(
      groups: [
        _SettingsGroup(
          icon: FontAwesomeIcons.circleInfo,
          title: strings.about,
          description: strings.aboutDescription,
          sections: [
            _SettingsSubsection(
              title: strings.application,
              children: [
                _InfoRow(
                  label: strings.applicationName,
                  value: strings.windowTitle,
                ),
                _InfoRow(
                  label: strings.guiVersion,
                  value: app_versions.guiVersion,
                ),
                _InfoRow(
                  label: strings.anycastScoutCoreVersion,
                  value: app_versions.anycastScoutCoreVersion,
                ),
                _InfoRow(
                  label: strings.singBoxCoreVersion,
                  value: app_versions.singBoxCoreVersion,
                ),
                _InfoRow(
                  label: strings.developers,
                  value: strings.pingleSoftware,
                ),
                _InfoRow(
                  label: strings.iconAttribution,
                  value: strings.fontAwesomeAttribution,
                ),
                _LinkInfoRow(
                  label: strings.website,
                  value: strings.pingleWebsite,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfigTextField {
  const _ConfigTextField({
    required this.label,
    required this.configKey,
    required this.enabled,
    this.pathAware = true,
    this.hint,
    this.editable = false,
  });

  final String label;
  final String configKey;
  final bool enabled;
  final bool pathAware;
  final String? hint;
  final bool editable;
}

List<Widget> _configTextRows(
  DashboardState state,
  DashboardController controller,
  List<_ConfigTextField> fields,
) {
  return [
    for (final field in fields)
      _ConfigTextRow(
        state: state,
        controller: controller,
        label: field.label,
        configKey: field.configKey,
        enabled: field.enabled,
        pathAware: field.pathAware,
        hint: field.hint,
        editable: field.editable,
      ),
  ];
}

class _ConfigTextRow extends StatelessWidget {
  const _ConfigTextRow({
    required this.state,
    required this.controller,
    required this.label,
    required this.configKey,
    required this.enabled,
    this.pathAware = true,
    this.hint,
    this.editable = false,
    this.trailing,
  });

  final DashboardState state;
  final DashboardController controller;
  final String label;
  final String configKey;
  final bool enabled;
  final bool pathAware;
  final String? hint;
  final bool editable;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _TextRow(
      label: label,
      value: state.text(configKey),
      enabled: enabled,
      pathAware: pathAware,
      hint: hint,
      editable: editable,
      onChanged: (value) => controller.updateTextField(configKey, value),
      trailing: trailing,
    );
  }
}

class _BrowseButton extends StatelessWidget {
  const _BrowseButton({
    required this.pending,
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
  });

  final bool pending;
  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = IconButton.styleFrom(
      fixedSize: const Size.square(_settingsControlHeight),
      minimumSize: const Size.square(_settingsControlHeight),
      maximumSize: const Size.square(_settingsControlHeight),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      visualDensity: VisualDensity.compact,
    );

    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: enabled && !pending ? onPressed : null,
      style: style,
      icon: const FaIcon(
        FontAwesomeIcons.folderOpen,
        size: AppSizes.compactIcon,
      ),
    );
  }
}

class _SettingsSections extends StatelessWidget {
  const _SettingsSections({required this.groups});

  final List<_SettingsGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: groups.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.xl),
      itemBuilder: (context, index) {
        return SizedBox(width: double.infinity, child: groups[index]);
      },
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.icon,
    required this.title,
    required this.description,
    required this.sections,
  });

  final FaIconData icon;
  final String title;
  final String description;
  final List<_SettingsSubsection> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingsHeader(
          icon: icon,
          iconKey: ValueKey('settings-group-icon:$title'),
          title: title,
          description: description,
        ),
        const SizedBox(height: AppSpacing.md),
        ..._joinWithSpacing(
          sections,
          const SizedBox(height: AppSpacing.settingsSection),
        ),
      ],
    );
  }
}

class _SettingsSubsection extends StatelessWidget {
  const _SettingsSubsection({
    required this.children,
    this.icon,
    this.title,
    this.description,
  });

  final FaIconData? icon;
  final String? title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          _SettingsHeader(
            icon: icon,
            iconKey: ValueKey('settings-subsection-icon:$title'),
            title: title!,
            description: description,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ..._joinWithSpacing(children, const SizedBox(height: AppSpacing.md)),
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.icon,
    required this.iconKey,
    required this.title,
    required this.description,
  });

  final FaIconData? icon;
  final Key iconKey;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    return Row(
      children: [
        if (icon != null) ...[
          SizedBox.square(
            key: iconKey,
            dimension: AppSizes.controlHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Center(
                child: FaIcon(icon, size: AppSizes.icon, color: colors.primary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

List<Widget> _joinWithSpacing(List<Widget> children, Widget spacing) {
  return [
    for (var index = 0; index < children.length; index++) ...[
      if (index > 0) spacing,
      children[index],
    ],
  ];
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.label,
    required this.value,
    required this.enabled,
    this.pathAware = true,
    this.hint,
    this.editable = false,
    this.onChanged,
    this.trailing,
  });

  final String label;
  final String value;
  final bool enabled;
  final bool pathAware;
  final String? hint;
  final bool editable;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _SettingsField(
      label: label,
      hint: hint,
      control: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: editable
                ? _SettingsEditableField(
                    key: ValueKey('settings-value:$label'),
                    value: value,
                    enabled: enabled,
                    onChanged: onChanged,
                  )
                : _SettingsValueField(
                    key: ValueKey('settings-value:$label'),
                    value: value,
                    enabled: enabled,
                    pathAware: pathAware,
                  ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _SettingsValueField extends StatelessWidget {
  const _SettingsValueField({
    required this.value,
    required this.enabled,
    required this.pathAware,
    super.key,
  });

  final String value;
  final bool enabled;
  final bool pathAware;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final displayValue = pathAware ? _pathEllipsis(value) : value;
    return SizedBox(
      height: _settingsControlHeight,
      child: Tooltip(
        message: value,
        waitDuration: const Duration(milliseconds: 400),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: enabled ? palette.surface : palette.muted,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled ? palette.text : palette.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsEditableField extends HookWidget {
  const _SettingsEditableField({
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  static final TextInputFormatter _singleLineFormatter =
      FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'));

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: value);
    useEffect(() {
      if (controller.text == value) {
        return null;
      }

      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
      return null;
    }, [controller, value]);

    return TextField(
      controller: controller,
      enabled: enabled,
      expands: true,
      maxLines: null,
      minLines: null,
      style: Theme.of(context).textTheme.bodyMedium,
      textAlignVertical: TextAlignVertical.center,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      inputFormatters: [_singleLineFormatter],
      onChanged: onChanged,
    );
  }
}

String _pathEllipsis(String value) {
  final separator = value.contains('\\') && !value.contains('/') ? '\\' : '/';
  final parts = value
      .split(separator)
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length < 3) {
    return value;
  }
  return ['...', parts[parts.length - 2], parts.last].join(separator);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return _SettingsField(
      label: label,
      control: SizedBox(
        height: AppSizes.controlHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.muted,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                value,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textMuted,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkInfoRow extends StatelessWidget {
  const _LinkInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final uri = Uri.parse(value);
    return _SettingsField(
      label: label,
      control: SizedBox(
        height: AppSizes.controlHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.muted,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('settings-link:$value'),
              borderRadius: BorderRadius.circular(AppRadii.md),
              mouseCursor: SystemMouseCursors.click,
              onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: palette.primary),
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

class _SegmentedRow<T extends Object> extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.tooltips = const {},
  });

  final String label;
  final T value;
  final Map<T, String> values;
  final ValueChanged<T>? onChanged;
  final Map<T, String> tooltips;

  @override
  Widget build(BuildContext context) {
    return _SettingsField(
      label: label,
      control: _CompactSegmentedButton<T>(
        value: value,
        values: values,
        tooltips: tooltips,
        onChanged: onChanged,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.strings,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final bool value;
  final bool enabled;
  final AppStrings strings;
  final ValueChanged<bool> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return _SettingsField(
      label: label,
      hint: hint,
      control: _CompactSegmentedButton<bool>(
        value: value,
        values: {true: strings.on, false: strings.off},
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _DropdownRow<T extends Object> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.values,
    required this.emptyValue,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String emptyValue;
  final bool enabled;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final menuValues = values.isEmpty ? <T>[] : values;
    final selectedValue = menuValues.contains(value) ? value : null;
    final emptyText = selectedValue == null ? emptyValue : null;
    return _SettingsField(
      label: label,
      control: InputDecorator(
        key: ValueKey('settings-dropdown:$label'),
        decoration: _settingsDropdownDecoration,
        isEmpty: selectedValue == null,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: selectedValue,
            isDense: true,
            isExpanded: true,
            menuWidth: _settingsDropdownMenuWidth,
            padding: _settingsDropdownPadding,
            icon: const FaIcon(
              FontAwesomeIcons.chevronDown,
              size: AppSizes.compactIcon,
            ),
            borderRadius: BorderRadius.circular(AppRadii.md),
            style: Theme.of(context).textTheme.bodyMedium,
            hint: emptyText == null
                ? null
                : Text(emptyText, maxLines: 1, overflow: TextOverflow.ellipsis),
            selectedItemBuilder: (context) => [
              for (final item in menuValues)
                Text(
                  item.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
            items: [
              for (final item in menuValues)
                DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    item.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: enabled && menuValues.isNotEmpty
                ? (value) => value == null ? null : onChanged(value)
                : null,
          ),
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.triangleExclamation,
              size: AppSizes.compactIcon,
              color: colors.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSegmentedButton<T extends Object> extends StatelessWidget {
  const _CompactSegmentedButton({
    required this.value,
    required this.values,
    required this.onChanged,
    this.tooltips = const {},
  });

  final T value;
  final Map<T, String> values;
  final ValueChanged<T>? onChanged;
  final Map<T, String> tooltips;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final entry in values.entries)
          ButtonSegment<T>(
            value: entry.key,
            label: Text(entry.value),
            tooltip: tooltips[entry.key],
          ),
      ],
      selected: {value},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.first),
    );
  }
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({required this.label, required this.control, this.hint});

  final String label;
  final Widget control;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (hint != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: hint!,
                waitDuration: const Duration(milliseconds: 400),
                child: FaIcon(
                  FontAwesomeIcons.circleInfo,
                  size: AppSizes.compactIcon,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        control,
      ],
    );
  }
}
