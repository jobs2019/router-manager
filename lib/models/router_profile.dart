enum IpMode {
  automatic,
  staticIp,
}

enum RouterType {
  suncommSe06Pro,
  huaweiHg8145x6,
  mikrotik,
  zte,
  other,
}

class RouterProfile {
  final String name;
  final RouterType routerType;
  final String defaultIp;
  final String currentIp;
  final IpMode ipMode;

  const RouterProfile({
    required this.name,
    required this.routerType,
    required this.defaultIp,
    required this.currentIp,
    required this.ipMode,
  });

  String get routerTypeName {
    switch (routerType) {
      case RouterType.suncommSe06Pro:
        return 'Suncomm SE06 Pro';
      case RouterType.huaweiHg8145x6:
        return 'Huawei HG8145X6';
      case RouterType.mikrotik:
        return 'MikroTik';
      case RouterType.zte:
        return 'ZTE';
      case RouterType.other:
        return 'Other';
    }
  }
}