class HuaweiWanConfiguration {
  const HuaweiWanConfiguration({
    required this.domain,
    required this.wanName,
    required this.status,
    required this.vlanId,
    required this.username,
    required this.password,
    required this.bindings,
  });

  final String domain;
  final String wanName;
  final String status;
  final String vlanId;
  final String username;
  final String password;
  final List<String> bindings;
}
