import 'package:flutter/material.dart';
import '../models/router_profile.dart';
import 'router_ip_screen.dart';

class RouterTypeScreen extends StatefulWidget {
  final String detectedIp;

  const RouterTypeScreen({
    super.key,
    required this.detectedIp,
  });

  @override
  State<RouterTypeScreen> createState() => _RouterTypeScreenState();
}

class _RouterTypeScreenState extends State<RouterTypeScreen> {
  RouterType _selectedType = RouterType.suncommSe06Pro;

  String _defaultIp(RouterType type) {
    switch (type) {
      case RouterType.suncommSe06Pro:
        return '192.168.100.1';
      case RouterType.huaweiEg8145v5:
        return '192.168.100.1';
      case RouterType.mikrotik:
        return '192.168.88.1';
      case RouterType.zte:
        return '192.168.1.1';
      case RouterType.other:
        return '';
    }
  }

  String _name(RouterType type) {
    switch (type) {
      case RouterType.suncommSe06Pro:
        return 'Suncomm SE06 Pro';
      case RouterType.huaweiEg8145v5:
        return 'Huawei EG8145V5';
      case RouterType.mikrotik:
        return 'MikroTik';
      case RouterType.zte:
        return 'ZTE';
      case RouterType.other:
        return 'Other';
    }
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouterIpScreen(
          detectedIp: widget.detectedIp,
          routerType: _selectedType,
          defaultIp: _defaultIp(_selectedType),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Router'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What type of router are you managing?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Detected gateway: ${widget.detectedIp}',
            ),
            const SizedBox(height: 24),
            Expanded(
              child: RadioGroup<RouterType>(
                groupValue: _selectedType,
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedType = value;
                  });
                },
                child: ListView(
                  children: RouterType.values.map((type) {
                    return Card(
                      child: RadioListTile<RouterType>(
                        value: type,
                        title: Text(_name(type)),
                        subtitle: Text(
                          _defaultIp(type).isEmpty
                              ? 'Manual IP'
                              : 'Default IP: ${_defaultIp(type)}',
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _continue,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
