import 'dart:convert';
import 'dart:io';

import 'package:anycast_scout_gui/src/features/probe_session/domain/dashboard_state.dart';
import 'package:anycast_scout_gui/src/features/probe_session/domain/discovery_profile.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/core_runner.dart';
import 'package:anycast_scout_gui/src/features/probe_session/infrastructure/workspace_locator.dart';

const defaultCloudflareAsnList = 'AS13335,AS209242,AS14789,AS395747,AS394536';
const defaultOutboundTag = '🇩🇪 Germany CDN 1';

Map<String, dynamic> defaultConfigValues(String workspaceRoot) {
  final defaults = Map<String, dynamic>.from(
    ScoutConfig.fromJson({'launch_cwd': workspaceRoot}).values,
  );
  defaults['session_path'] = '$workspaceRoot/anycast-scout-session.json';
  defaults['targets_output'] = '$workspaceRoot/cf-edge-targets.csv';
  defaults['scan_output'] = '$workspaceRoot/cf-edge-selected.csv';
  defaults['urltest_output'] = '$workspaceRoot/cf-edge-urltests.jsonl';
  defaults['sing_box_config'] = selectJsonConfigFile;
  defaults['urltest_concurrency'] = '4';
  defaults['max_valid'] = '';
  defaults['asn_list'] = defaultCloudflareAsnList;
  defaults[DiscoveryProfile.configKey] =
      DiscoveryProfile.cloudflareCandidates.name;
  defaults['speed_url'] = 'https://speed.cloudflare.com/__down?bytes=10000000';
  defaults['download_url'] = 'https://speed.cloudflare.com/__down?bytes=20480';
  defaults['min_download_bytes'] = '20480';
  return normalizeConfigValues(workspaceRoot, defaults);
}

ScoutConfig buildConfig(DashboardState state) {
  return ScoutConfig.fromJson(
    normalizeConfigValues(state.workspaceRoot, state.config),
  );
}

Map<String, dynamic> normalizeConfigValues(
  String workspaceRoot,
  Map<String, dynamic> values,
) {
  final next = Map<String, dynamic>.from(values);
  next['launch_cwd'] = workspaceRoot;

  final profile = DiscoveryProfile.fromConfigValue(
    next[DiscoveryProfile.configKey],
    next['asn_list']?.toString() ?? '',
  );
  next[DiscoveryProfile.configKey] = profile.name;
  if (profile == DiscoveryProfile.cloudflareCandidates) {
    next['asn_list'] = defaultCloudflareAsnList;
    next['limit_targets'] = false;
  }

  for (final key in const [
    'session_path',
    'input_path',
    'targets_output',
    'scan_output',
    'urltest_output',
    'sing_box_config',
  ]) {
    next[key] = normalizeConfigPath(workspaceRoot, next[key]?.toString() ?? '');
  }
  return next;
}

DashboardState applyLoadedConfig(
  DashboardState current,
  Map<String, dynamic> loaded,
) {
  return current.copyWith(
    config: normalizeConfigValues(current.workspaceRoot, loaded),
    formVersion: current.formVersion + 1,
  );
}

String? localSingBoxConfigMissingWarning(DashboardState state) {
  final config = buildConfig(state);
  final source = config.text('sing_box_config').trim();
  if (source.isEmpty ||
      source.startsWith('http://') ||
      source.startsWith('https://')) {
    return null;
  }
  final file = File(config.resolvePath(source));
  return file.existsSync() ? null : file.path;
}

List<String> localSingBoxOutboundTags(DashboardState state) {
  final config = buildConfig(state);
  return singBoxOutboundTagsFromPath(
    state.workspaceRoot,
    config.text('sing_box_config'),
  );
}

List<String> singBoxOutboundTagsFromPath(String workspaceRoot, String source) {
  final trimmedSource = source.trim();
  if (trimmedSource.isEmpty ||
      trimmedSource.startsWith('http://') ||
      trimmedSource.startsWith('https://')) {
    return const [];
  }

  final file = File(normalizeConfigPath(workspaceRoot, trimmedSource));
  if (!file.existsSync()) {
    return const [];
  }

  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      return const [];
    }
    final outbounds = decoded['outbounds'];
    if (outbounds is! List) {
      return const [];
    }
    final tags = <String>[];
    for (final outbound in outbounds.whereType<Map>()) {
      final tag = outbound['tag']?.toString().trim() ?? '';
      if (tag.isNotEmpty && !tags.contains(tag)) {
        tags.add(tag);
      }
    }
    return tags;
  } catch (_) {
    return const [];
  }
}
