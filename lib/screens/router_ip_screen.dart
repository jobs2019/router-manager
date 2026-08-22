import 'package:flutter/material.dart';
import '../models/router_profile.dart';
import '../services/router_discovery.dart';
import 'huawei_test_screen.dart';
import 'login_screen.dart';

class RouterIpScreen extends StatefulWidget {
  final String? detectedIp;
  final RouterType? routerType;
  final String? defaultIp;

  const RouterIpScreen({
    super.key,
    this.detectedIp,
    this.routerType,
    this.defaultIp,
  });

  @override
  State<RouterIpScreen> createState() => _RouterIpScreenState();
}

class _RouterIpScreenState extends State<RouterIpScreen> {
  final RouterDiscovery _discovery = RouterDiscovery();

  late final TextEditingController _ipController;

  IpMode _ipMode = IpMode.automatic;

  bool _testing = false;
  bool? _reachable;
  String? _message;

  @override
  void initState() {
    super.initState();

    _ipController = TextEditingController(
      text: widget.detectedIp ??
          widget.defaultIp ??
          '',
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _testIp() async {
    final ip = _ipController.text.trim();

    if (ip.isEmpty) {
      setState(() {
        _reachable = false;
        _message = 'Please enter an IP address.';
      });
      return;
    }

    setState(() {
      _testing = true;
      _reachable = null;
      _message = null;
    });

    final reachable = await _discovery.testRouter(ip);

    if (!mounted) return;

    setState(() {
      _testing = false;
      _reachable = reachable;
      _message = reachable
          ? 'Router is reachable.'
          : 'Router did not respond.';
    });
  }

  void _continue() {
    if (_reachable != true) {
      return;
    }

    final type = widget.routerType ?? RouterType.other;
    final ip = _ipController.text.trim();

    // Huawei has its own login screen, so skip the generic
    // Administrator Login page after router IP configuration.
    if (type == RouterType.huaweiEg8145v5) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HuaweiTestScreen(
            routerIp: ip,
          ),
        ),
      );
      return;
    }

    final profile = RouterProfile(
      name: _routerName(type),
      routerType: type,
      defaultIp: widget.defaultIp ?? '',
      currentIp: ip,
      ipMode: _ipMode,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          profile: profile,
        ),
      ),
    );
  }

  String _routerName(RouterType type) {
    switch (type) {
      case RouterType.suncommSe06Pro:
        return 'SE06 Pro';
      case RouterType.huaweiEg8145v5:
        return 'Huawei EG8145V5';
      case RouterType.mikrotik:
        return 'MikroTik';
      case RouterType.zte:
        return 'ZTE';
      case RouterType.other:
        return 'Router';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Router IP'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Router IP Configuration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            RadioGroup<IpMode>(
              groupValue: _ipMode,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _ipMode = value;

                  if (value == IpMode.automatic &&
                      widget.detectedIp != null) {
                    _ipController.text = widget.detectedIp!;
                  }

                  if (value == IpMode.staticIp &&
                      _ipController.text.isEmpty &&
                      widget.defaultIp != null) {
                    _ipController.text = widget.defaultIp!;
                  }
                });
              },
              child: Column(
                children: [
                  RadioListTile<IpMode>(
                    value: IpMode.automatic,
                    title: const Text('Automatic'),
                    subtitle: Text(
                      widget.detectedIp == null
                          ? 'Use the detected/default gateway'
                          : 'Detected gateway: ${widget.detectedIp}',
                    ),
                  ),
                  RadioListTile<IpMode>(
                    value: IpMode.staticIp,
                    title: const Text('Static IP'),
                    subtitle: const Text(
                      'Manually specify the router IP',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Router IP Address',
                hintText: '192.168.1.1',
                border: OutlineInputBorder(),
              ),
            ),

            if (widget.defaultIp != null &&
                widget.defaultIp!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Default IP: ${widget.defaultIp}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _testing ? null : _testIp,
                icon: _testing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.network_check),
                label: Text(
                  _testing ? 'Testing...' : 'Test Connection',
                ),
              ),
            ),

            if (_message != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    _reachable == true
                        ? Icons.check_circle
                        : Icons.error,
                    color: _reachable == true
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_message!)),
                ],
              ),
            ],

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _reachable == true ? _continue : null,
                child: Text(
                  widget.routerType == RouterType.huaweiEg8145v5
                      ? 'Continue to Huawei Login'
                      : 'Continue to Login',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
