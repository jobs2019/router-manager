import 'package:flutter/material.dart';

import 'huawei_device_access_control_screen.dart';
import 'huawei_test_screen.dart';

/// Keeps the existing Huawei dashboard intact while exposing the first
/// confirmed Device Access Control module.
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'huawei-device-access-control',
        icon: const Icon(Icons.devices_rounded),
        label: const Text('Access Control'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HuaweiDeviceAccessControlScreen(
                routerIp: routerIp,
                username: 'telecomadmin',
                password: 'admintelecom',
              ),
            ),
          );
        },
      ),
    );
  }
}
