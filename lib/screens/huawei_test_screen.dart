import 'package:flutter/material.dart';

import '../services/huawei_api.dart';
import 'huawei_wifi_settings_screen.dart';

class HuaweiTestScreen extends StatefulWidget {
  const HuaweiTestScreen({
    super.key,
    this.routerIp = '192.168.100.1',
  });

  final String routerIp;

  @override
  State<HuaweiTestScreen> createState() => _HuaweiTestScreenState();
}

class _HuaweiTestScreenState extends State<HuaweiTestScreen> {
  late final HuaweiApi _api;

  final TextEditingController _usernameController = TextEditingController(text: 'telecomadmin');
  final TextEditingController _passwordController = TextEditingController(text: 'admintelecom');

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
      setState(() => _loggedIn = true);
      await _loadWan();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    }
    if (!mounted) return;
    setState(() => _loading = false);
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
      setState(() => _wanData = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    }
    if (!mounted) return;
    setState(() => _loadingWan = false);
  }

  String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');

  Widget _sectionTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
    ],
  );

  Widget _buildRouterHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB00020), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.router_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Huawei EG8145V5', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(widget.routerIp, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Icon(_loggedIn ? Icons.check_circle : Icons.lock_outline, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Administrator Login', 'Sign in to manage this ONT locally.'),
            const SizedBox(height: 18),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _loginHuawei,
                icon: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login_rounded),
                label: Text(_loading ? 'Connecting...' : 'Connect to Huawei'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 95, child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value == null || value.isEmpty ? '--' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    ),
  );

  Widget _buildWanCard() {
    if (_loadingWan) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
        child: const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
      );
    }
    if (_wanData == null || _wanData!.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _sectionTitle('WAN Information', '${_wanData!.length} connection${_wanData!.length == 1 ? '' : 's'} detected')),
                IconButton(tooltip: 'Refresh', onPressed: _loadingWan ? null : _loadWan, icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            ..._wanData!.asMap().entries.map((entry) {
              final index = entry.key;
              final wan = entry.value;
              final connected = (wan['status'] ?? '').toLowerCase() == 'connected';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(child: Text(wan['wanName'] ?? '--', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: connected ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          wan['status'] ?? '--',
                          style: TextStyle(color: connected ? Colors.green.shade700 : Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow('IP Address', wan['ipAddress']),
                  _infoRow('VLAN ID', wan['vlanId']),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _featureTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: const Color(0xFFB00020).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: const Color(0xFFB00020)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSection() {
    if (!_loggedIn) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Router Management', 'Quick access to Huawei network controls.'),
        const SizedBox(height: 12),
        _featureTile(
          icon: Icons.wifi_rounded,
          title: '2.4 GHz Wi-Fi',
          subtitle: 'Change 2.4 GHz Wi-Fi name and password',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HuaweiWifiSettingsScreen(api: _api))),
        ),
        const SizedBox(height: 10),
        _featureTile(
          icon: Icons.devices_rounded,
          title: 'Device Access Control',
          subtitle: 'Blocklist, allowlist and connected devices',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device Access Control is the next Huawei module.'))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('Router Manager', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRouterHeader(),
              const SizedBox(height: 16),
              if (!_loggedIn) _buildLoginCard(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
              if (_loggedIn) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(child: Text('Logged in successfully. Huawei management features are available.')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildWanCard(),
                const SizedBox(height: 18),
                _buildFeatureSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
