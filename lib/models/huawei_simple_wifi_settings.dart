class HuaweiSimpleWifiBandSettings {
  final bool enabled;
  final String ssid;
  final bool broadcastSsid;
  final bool wmmEnabled;
  final bool staIsolation;
  final int maxAssociateNum;

  const HuaweiSimpleWifiBandSettings({
    required this.enabled,
    required this.ssid,
    required this.broadcastSsid,
    required this.wmmEnabled,
    required this.staIsolation,
    required this.maxAssociateNum,
  });
}

class HuaweiSimpleWifiSettings {
  final HuaweiSimpleWifiBandSettings band2G;
  final HuaweiSimpleWifiBandSettings band5G;

  const HuaweiSimpleWifiSettings({
    required this.band2G,
    required this.band5G,
  });
}
