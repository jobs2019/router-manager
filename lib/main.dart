import 'package:flutter/material.dart';
import 'screens/huawei_test_screen.dart';

void main() {
  runApp(const RouterManagerApp());
}

class RouterManagerApp extends StatelessWidget {
  const RouterManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Router Manager',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const HuaweiTestScreen(
        routerIp: '192.168.100.1',
      ),
    );
  }
}