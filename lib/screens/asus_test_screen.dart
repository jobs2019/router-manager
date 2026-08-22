import 'package:flutter/material.dart';

import '../services/asus_api.dart';

class AsusTestScreen extends StatefulWidget {
  const AsusTestScreen({
    super.key,
    required this.routerIp,
  });

  final String routerIp;

  @override
  State<AsusTestScreen> createState() =>
      _AsusTestScreenState();
}

class _AsusTestScreenState
    extends State<AsusTestScreen> {
  late final AsusApi _api;

  final TextEditingController _usernameController =
      TextEditingController(text: 'admin');

  final TextEditingController _passwordController =
      TextEditingController();

  bool _loading = false;
  bool _loggedIn = false;

  String? _error;

  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();

    _api = AsusApi(
      baseUrl: 'http://${widget.routerIp}',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginAndRead() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _api.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      final status = await _api.getStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _loggedIn = true;
        _status = status;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loggedIn = false;
        _status = null;
        _error = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });
  }

  String _value(
    String section,
    String key,
  ) {
    final sectionData = _status?[section];

    if (sectionData is! Map) {
      return '—';
    }

    final value = sectionData[key];

    if (value == null ||
        value.toString().isEmpty) {
      return '—';
    }

    return value.toString();
  }

  Widget _infoCard(
    String title,
    List<Widget> children,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ASUS RT-AC87U Test',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Router: ${widget.routerIp}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed:
                  _loading ? null : _loginAndRead,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Login & Read Status',
                    ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],

          if (_loggedIn &&
              _status != null) ...[
            const SizedBox(height: 20),

            const Text(
              'Connection successful',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _infoCard(
              'WAN / Internet',
              [
                _row(
                  'Internet',
                  _value(
                    'wan',
                    'link_internet',
                  ),
                ),
                _row(
                  'WAN IP',
                  _value(
                    'wan',
                    'wan0_ipaddr',
                  ),
                ),
                _row(
                  'Active WAN',
                  _value(
                    'wan',
                    'active_wan_unit',
                  ),
                ),
                _row(
                  'WAN Enabled',
                  _value(
                    'wan',
                    'wan0_enable',
                  ),
                ),
              ],
            ),

            _infoCard(
              'Wi-Fi',
              [
                _row(
                  'Wi-Fi switch',
                  _value(
                    'wifi',
                    'wifi_hw_switch',
                  ),
                ),
                _row(
                  '2.4 GHz radio',
                  _value(
                    'wifi',
                    'wlan0_radio_flag',
                  ),
                ),
                _row(
                  '5 GHz radio',
                  _value(
                    'wifi',
                    'wlan1_radio_flag',
                  ),
                ),
                _row(
                  '2.4 GHz rate',
                  _value(
                    'wifi',
                    'data_rate_info_2g',
                  ),
                ),
                _row(
                  '5 GHz rate',
                  _value(
                    'wifi',
                    'data_rate_info_5g',
                  ),
                ),
                _row(
                  '2.4 GHz RSSI',
                  _value(
                    'wifi',
                    'rssi_2g',
                  ),
                ),
                _row(
                  '5 GHz RSSI',
                  _value(
                    'wifi',
                    'rssi_5g',
                  ),
                ),
              ],
            ),

            _infoCard(
              'System',
              [
                _row(
                  'Uptime',
                  _value(
                    'system',
                    'uptime',
                  ),
                ),
              ],
            ),

            _infoCard(
              'VPN',
              [
                _row(
                  'VPN protocol',
                  _value(
                    'vpn',
                    'vpnc_proto',
                  ),
                ),
                _row(
                  'VPN state',
                  _value(
                    'vpn',
                    'vpnc_state',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}