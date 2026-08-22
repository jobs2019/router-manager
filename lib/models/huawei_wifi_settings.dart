class HuaweiWifiSettings {
  final bool enabled;
  final String ssid;
  final bool broadcastSsid;
  final bool wmmEnabled;
  final int maxAssociateNum;
  final String authenticationMode;
  final String encryptionMode;
  final int groupRekey;
  final bool wpsEnabled;

  const HuaweiWifiSettings({
    required this.enabled,
    required this.ssid,
    required this.broadcastSsid,
    required this.wmmEnabled,
    required this.maxAssociateNum,
    required this.authenticationMode,
    required this.encryptionMode,
    required this.groupRekey,
    required this.wpsEnabled,
  });

  HuaweiWifiSettings copyWith({
    bool? enabled,
    String? ssid,
    bool? broadcastSsid,
    bool? wmmEnabled,
    int? maxAssociateNum,
    String? authenticationMode,
    String? encryptionMode,
    int? groupRekey,
    bool? wpsEnabled,
  }) {
    return HuaweiWifiSettings(
      enabled: enabled ?? this.enabled,
      ssid: ssid ?? this.ssid,
      broadcastSsid: broadcastSsid ?? this.broadcastSsid,
      wmmEnabled: wmmEnabled ?? this.wmmEnabled,
      maxAssociateNum: maxAssociateNum ?? this.maxAssociateNum,
      authenticationMode: authenticationMode ?? this.authenticationMode,
      encryptionMode: encryptionMode ?? this.encryptionMode,
      groupRekey: groupRekey ?? this.groupRekey,
      wpsEnabled: wpsEnabled ?? this.wpsEnabled,
    );
  }
}
