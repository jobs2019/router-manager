import 'package:flutter/material.dart';
import '../services/router_discovery.dart';
import 'router_type_screen.dart';
import 'router_ip_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final RouterDiscovery _discovery = RouterDiscovery();

  bool _loading = true;
  String? _gateway;
  String? _wifiIp;
  String? _error;

  @override
  void initState() {
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final gateway = await _discovery.detectGateway();
    final wifiIp = await _discovery.getWifiIp();

    if (!mounted) return;

    if (gateway == null || gateway.isEmpty) {
      setState(() {
        _loading = false;
        _gateway = null;
        _wifiIp = wifiIp;
        _error = 'Gateway could not be detected.';
      });
      return;
    }

    final reachable = await _discovery.testRouter(gateway);

    if (!mounted) return;

    setState(() {
      _loading = false;
      _gateway = gateway;
      _wifiIp = wifiIp;
    });

    if (reachable) {
      _showDetectedRouter(gateway);
    } else {
      setState(() {
        _error = 'Gateway detected, but no HTTP service responded.';
      });
    }
  }

  void _showDetectedRouter(String gateway) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RouterTypeScreen(
            detectedIp: gateway,
          ),
        ),
      );
    });
  }

  void _manualIp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RouterIpScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: _loading
                ? _buildLoading()
                : _buildResult(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.router,
          size: 64,
        ),
        const SizedBox(height: 24),
        const Text(
          'Finding your router',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Detecting the Wi-Fi gateway...',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _gateway != null
              ? Icons.router
              : Icons.warning_amber_rounded,
          size: 64,
        ),
        const SizedBox(height: 24),
        Text(
          _gateway != null
              ? 'Router Gateway Found'
              : 'Router Not Detected',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_wifiIp != null)
          Text(
            'Phone IP: $_wifiIp',
            style: const TextStyle(fontSize: 15),
          ),
        if (_gateway != null) ...[
          const SizedBox(height: 8),
          Text(
            'Gateway: $_gateway',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 28),
        if (_gateway == null)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _manualIp,
              child: const Text('Enter Router IP'),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _discover,
            child: const Text('Try Again'),
          ),
        ),
      ],
    );
  }
}