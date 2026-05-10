enum DiscoveryProfile {
  cloudflareCandidates,
  custom;

  static const configKey = 'discovery_profile';

  static DiscoveryProfile fromConfigValue(Object? value, String asnList) {
    final raw = value?.toString();
    if (raw == custom.name) {
      return DiscoveryProfile.custom;
    }
    if (raw == cloudflareCandidates.name) {
      return DiscoveryProfile.cloudflareCandidates;
    }

    final normalized = asnList.replaceAll(RegExp(r'[\s,]+'), '').toUpperCase();
    return normalized == 'AS13335'
        ? DiscoveryProfile.cloudflareCandidates
        : DiscoveryProfile.custom;
  }
}
