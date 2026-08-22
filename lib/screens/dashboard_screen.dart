import 'package:flutter/material.dart';

import '../services/se06_api.dart';
import 'connected_devices_screen.dart';
import 'wifi_settings_screen.dart';
import 'signal_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Se06Api api;
  final String routerName;

  const DashboardScreen({
    super.key,
    required this.api,
    this.routerName = 'SE06_Pro',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _routerName = 'SE06_Pro';
  String _internet = 'Unknown';
  String _network = 'Unknown';
  String _devices = '—';
  String _uptime = 'Unknown';
  String _wifiName = 'Unknown';

  bool _loading = true;
  bool _connected = true;

  @override
  void initState() {
    super.initState();

    _routerName = widget.routerName;

    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final dashboardData = await widget.api.dashboard();

      final result = dashboardData['result'];

      if (result is Map) {
        _parseDashboard(result);
      }

      await _loadDeviceCount();
      await _loadWifiName();

      if (!mounted) return;

      setState(() {
        _connected = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _connected = false;
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to refresh router data: $e',
          ),
        ),
      );
    }
  }

  void _parseDashboard(Map result) {
    String internet = 'Unknown';
    String network = 'Unknown';
    String uptime = 'Unknown';
    String wifi = 'Unknown';

    /*
     * Internet
     *
     * The SE06 dashboard response contains:
     *
     * internet.status
     *
     * 0 = online in the response we observed.
     */
    final internetData = result['internet'];

    if (internetData is Map) {
      final status = internetData['status'];

      if (status == 0) {
        internet = 'Online';
      } else if (status != null) {
        internet = 'Offline';
      }
    }

    /*
     * Network
     *
     * The SE06 response contains LTE information.
     * LTE_NSA = 1 indicates 5G NSA.
     */
    final lte = result['lte'];

    if (lte is Map) {
      final info = lte['info'];

      if (info is Map) {
        final nsa = info['LTE_NSA'];
        final lte5g = info['LTE_5G'];

        if (nsa == 1 || lte5g == 1 || lte5g == 2) {
          network = '5G';
        } else if (info['LTE_4G'] == 1) {
          network = '4G';
        }
      }
    }

    /*
     * Uptime
     */
    final uptimeValue = result['uptime'];

    if (uptimeValue != null) {
      uptime = _formatUptime(uptimeValue);
    }

    /*
     * Wi-Fi
     *
     * We will retrieve the actual SSID from the Wi-Fi API
     * in the next step. For now we safely leave it as Unknown.
     */
    final possibleWifi = result['wifi'];

    if (possibleWifi is Map) {
      final possibleSsid =
          possibleWifi['ssid'] ??
          possibleWifi['name'];

      if (possibleSsid != null &&
          possibleSsid.toString().trim().isNotEmpty) {
        wifi = possibleSsid.toString();
      }
    }

    if (!mounted) return;

    setState(() {
      _internet = internet;
      _network = network;
      _uptime = uptime;
      _wifiName = wifi;
    });
  }

  Future<void> _loadDeviceCount() async {
    try {
      final data = await widget.api.getDevices();

      final result = data['result'];

      final deviceList =
          result is Map && result['device'] is List
              ? result['device'] as List
              : <dynamic>[];

      if (!mounted) return;

      setState(() {
        _devices = deviceList.length.toString();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _devices = '—';
      });
    }
  }

Future<void> _loadWifiName() async {
  try {
    final data = await widget.api.getWifi();

    final result = data['result'];

    if (result is! Map) {
      return;
    }

    final master = result['master'];

    if (master is! Map) {
      return;
    }

    final ssid = master['ssid'];

    if (ssid == null || ssid.toString().trim().isEmpty) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _wifiName = ssid.toString();
    });
  } catch (_) {
    if (!mounted) return;

    setState(() {
      _wifiName = 'Unknown';
    });
  }
}

  String _formatUptime(dynamic value) {
    final seconds = int.tryParse(
          value.toString(),
        ) ??
        0;

    if (seconds <= 0) {
      return 'Unknown';
    }

    final duration = Duration(
      seconds: seconds,
    );

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h';
    }

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  void _openConnectedDevices() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectedDevicesScreen(
          api: widget.api,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Router Manager'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRouterHeader(),

              const SizedBox(height: 24),

              _buildStatusCard(),

              const SizedBox(height: 20),

              _buildWifiCard(),

              const SizedBox(height: 12),

              _buildDevicesCard(),

              const SizedBox(height: 12),

              _buildSignalCard(),

              const SizedBox(height: 30),

              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouterHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _routerName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _connected
                    ? Colors.green
                    : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),

            const SizedBox(width: 8),

            Text(
              _connected
                  ? 'Connected'
                  : 'Not Connected',
              style: TextStyle(
                fontSize: 16,
                color: _connected
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            StatusRow(
              label: 'Internet',
              value: _internet,
            ),

            const Divider(),

            StatusRow(
              label: 'Network',
              value: _network,
            ),

            const Divider(),

            StatusRow(
              label: 'Connected Devices',
              value: _devices,
            ),

            const Divider(),

            StatusRow(
              label: 'Uptime',
              value: _uptime,
            ),
          ],
        ),
      ),
    );
  }

Widget _buildWifiCard() {
  return Card(
    child: ListTile(
      leading: const Icon(
        Icons.wifi,
      ),
      title: const Text(
        'Wi-Fi',
      ),
      subtitle: Text(
        _wifiName,
      ),
      trailing: const Icon(
        Icons.chevron_right,
      ),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => WifiSettingsScreen(
              api: widget.api,
            ),
          ),
        );

        if (changed == true && mounted) {
          await _loadDashboard();
        }
      },
    ),
  );
}

  Widget _buildDevicesCard() {
    final deviceCount = _devices == '—'
        ? 'View connected devices'
        : '$_devices devices connected';

    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.devices,
        ),
        title: const Text(
          'Connected Devices',
        ),
        subtitle: Text(
          deviceCount,
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: _openConnectedDevices,
      ),
    );
  }

Widget _buildSignalCard() {
  return Card(
    child: ListTile(
      leading: const Icon(
        Icons.signal_cellular_alt,
      ),
      title: const Text(
        '5G Signal',
      ),
      subtitle: const Text(
        'View mobile network information',
      ),
      trailing: const Icon(
        Icons.chevron_right,
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SignalScreen(
              api: widget.api,
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading
                ? null
                : _loadDashboard,
            icon: const Icon(
              Icons.refresh,
            ),
            label: const Text(
              'Refresh Router',
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openConnectedDevices,
            icon: const Icon(
              Icons.devices,
            ),
            label: const Text(
              'Connected Devices',
            ),
          ),
        ),
      ],
    );
  }
}

class StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const StatusRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}