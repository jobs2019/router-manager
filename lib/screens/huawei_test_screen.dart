import 'package:flutter/material.dart';

import '../services/huawei_api.dart';

class HuaweiTestScreen extends StatefulWidget {
  const HuaweiTestScreen({
    super.key,
    this.routerIp = '192.168.100.1',
  });

  final String routerIp;

  @override
  State<HuaweiTestScreen> createState() =>
      _HuaweiTestScreenState();
}

class _HuaweiTestScreenState extends State<HuaweiTestScreen> {
  late final HuaweiApi _api;

  final TextEditingController _usernameController =
      TextEditingController(text: 'telecomadmin');
  final TextEditingController _passwordController =
      TextEditingController(text: 'admintelecom');

  bool _loading = false;
  bool _loggedIn = false;
  bool _loadingWan = false;

  String? _error;
  List<Map<String, String>>? _wanData;

  @override
  void initState() {
    super.initState();
    _api = HuaweiApi(baseUrl: 'http://${widget.routerIp}');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginHuawei() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _loggedIn = false;
      _wanData = null;
    });

    try {
      await _api.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      setState(() {
        _loggedIn = true;
      });

      await _loadWan();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
      });
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadWan() async {
    if (!_loggedIn) return;

    setState(() {
      _loadingWan = true;
      _error = null;
    });

    try {
      final data = await _api.getWanStatus();

      if (!mounted) return;
      setState(() {
        _wanData = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
      });
    }

    if (!mounted) return;
    setState(() {
      _loadingWan = false;
    });
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value.isEmpty ? '--' : value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWanCard() {
    if (_loadingWan) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_wanData == null || _wanData!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WAN Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._wanData!.asMap().entries.map((entry) {
              final index = entry.key;
              final wan = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const Divider(height: 30),
                  Text(
                    wan['wanName'] ?? '--',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Status', wan['status']),
                  _infoRow('IP Address', wan['ipAddress']),
                  _infoRow('VLAN ID', wan['vlanId']),
                ],
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadingWan ? null : _loadWan,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh WAN Information'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Huawei Router Manager'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Huawei Login',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _loginHuawei,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            _loading ? 'Logging in...' : 'Login',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
              if (_loggedIn) ...[
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Logged in successfully. WAN information is available below.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildWanCard(),
            ],
          ),
        ),
      ),
    );
  }
}
