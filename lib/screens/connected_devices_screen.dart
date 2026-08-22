import 'package:flutter/material.dart';

import '../services/se06_api.dart';

class ConnectedDevicesScreen extends StatefulWidget {
  final Se06Api api;

  const ConnectedDevicesScreen({
    super.key,
    required this.api,
  });

  @override
  State<ConnectedDevicesScreen> createState() =>
      _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState
    extends State<ConnectedDevicesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.api.getDevices();

      final result = data['result'];

      final rawDevices = result is Map
          ? result['device']
          : null;

      final devices = <Map<String, dynamic>>[];

      if (rawDevices is List) {
        for (final device in rawDevices) {
          if (device is Map) {
            devices.add(
              Map<String, dynamic>.from(device),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Devices'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDevices,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to load devices',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loadDevices,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_devices.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDevices,
        child: ListView(
          children: const [
            SizedBox(height: 220),
            Center(
              child: Text(
                'No connected devices',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummary(),
          const SizedBox(height: 12),
          ..._devices.map(_buildDeviceCard),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.devices,
              size: 32,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connected Devices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_devices.length} device${_devices.length == 1 ? '' : 's'} connected',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(
    Map<String, dynamic> device,
  ) {
    final hostname =
        _stringValue(device['hostname'], 'Unknown device');

    final ip =
        _stringValue(device['ipaddr'], 'Unknown');

    final mac =
        _stringValue(device['macaddr'], 'Unknown');

    final access =
        _stringValue(device['access'], 'Unknown');

    final rxSpeed = _numberValue(device['rxspeed']);
    final txSpeed = _numberValue(device['txspeed']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.devices),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    hostname,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildAccessBadge(access),
              ],
            ),

            const SizedBox(height: 16),

            _infoRow(
              Icons.language,
              'IP Address',
              ip,
            ),

            const SizedBox(height: 8),

            _infoRow(
              Icons.fingerprint,
              'MAC Address',
              mac,
            ),

            const SizedBox(height: 8),

            _infoRow(
              Icons.wifi,
              'Connection',
              access,
            ),

            const Divider(height: 24),

            Row(
              children: [
                Expanded(
                  child: _speedInfo(
                    Icons.arrow_downward,
                    'Download',
                    _formatSpeed(rxSpeed),
                  ),
                ),
                Expanded(
                  child: _speedInfo(
                    Icons.arrow_upward,
                    'Upload',
                    _formatSpeed(txSpeed),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessBadge(String access) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.green.withValues(alpha: 0.12),
      ),
      child: Text(
        access,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _speedInfo(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _stringValue(
    dynamic value,
    String fallback,
  ) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  double _numberValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatSpeed(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} MB/s';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)} KB/s';
    }

    return '${value.toStringAsFixed(0)} B/s';
  }
}