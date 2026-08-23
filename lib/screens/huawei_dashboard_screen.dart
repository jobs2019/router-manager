import 'package:flutter/material.dart';

import 'huawei_test_screen.dart';

/// Huawei dashboard entry point.
class HuaweiDashboardScreen extends StatelessWidget {
  const HuaweiDashboardScreen({
    super.key,
    required this.routerIp,
  });

  final String routerIp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HuaweiTestScreen(routerIp: routerIp),
    );
  }
}
