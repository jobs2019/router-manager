import 'package:flutter/material.dart';

import '../services/huawei_api.dart';
import '../services/huawei_device_access_control.dart';
import 'huawei_device_access_control_screen.dart';
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
  late final HuaweiDeviceAccessControlService _accessControlService;

  final TextEditingController _usernameController = TextEditingController(text: 'telecomadmin');
  final TextEditingController _passwordController = TextEditingController(text: 'admintelecom');

  bool _loading = false;
  bool _loggedIn = false;
  bool _loadingWan = false;
  bool _loadingAccessSummary = false;

  String? _error;
  List<Map<String, String>>? _wanData;
  bool? _accessControlEnabled;
  List<int>? _accessControlEntryIndices;
  String? _accessControlError;

  @override
  void initState() {
    super.initState();
    _api = HuaweiApi(baseUrl: 'http://${widget.routerIp}');
    _accessControlService = HuaweiDeviceAccessControlService(
      baseUrl: 'http://${widget.routerIp}',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _accessControlService.close();
    super.dispose();
  }

  Future<void> _loginHuawei() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _loggedIn = false;
      _wanData = null;
      _accessControlEnabled = null;
      _accessControlEntryIndices = null;
      _accessControlError = null;
    });
    try {
      await _api.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _loggedIn = true);
      await Future.wait([
        _loadWan(),
        _loadAccessControlSummary(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out of this Huawei router?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
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

  Future<void> _loadAccessControlSummary() async {
    if (!_loggedIn) return;

    setState(() {
      _loadingAccessSummary = true;
      _accessControlError = null;
    });

    try {
      await _accessControlService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      final status = await _accessControlService.getStatus();
      final entries = await _accessControlService.getEntryIndices();

      if (!mounted) return;
      setState(() {
        _accessControlEnabled = status.enabled;
        _accessControlEntryIndices = entries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accessControlEnabled = null;
        _accessControlEntryIndices = null;
        _accessControlError = _cleanError(e);
      });
    } finally {
      if (mounted) setState(() => _loadingAccessSummary = false);
    }
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

  Widget _buildWanCard() {
    if (_loadingWan) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }
    if (_wanData == null || _wanData!.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'WAN Information',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${_wanData!.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  onPressed: _loadingWan ? null : _loadWan,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ..._wanData!.asMap().entries.map((entry) {
              final index = entry.key;
              final wan = entry.value;
              final connected = (wan['status'] ?? '').toLowerCase() == 'connected';
              final status = wan['status'] ?? '--';
              final ip = wan['ipAddress'] ?? '--';
              final vlan = wan['vlanId'] ?? '--';

              return Column(
                children: [
                  if (index > 0) Divider(height: 1, color: Colors.grey.shade200),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wan['wanName'] ?? '--',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'IP $ip  •  VLAN $vlan',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: connected ? Colors.green.withValues(alpha: 0.10) : Colors.orange.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: connected ? Colors.green.shade700 : Colors.orange.shade800,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessControlSummary() {
    final enabled = _accessControlEnabled;
    final entries = _accessControlEntryIndices;
    final hasEntries = entries?.isNotEmpty == true;

    String statusText;
    Color statusColor;

    if (_loadingAccessSummary) {
      statusText = 'Checking status...';
      statusColor = Colors.grey.shade700;
    } else if (_accessControlError != null) {
      statusText = 'Status unavailable';
      statusColor = Colors.orange.shade800;
    } else if (enabled == true) {
      statusText = hasEntries
          ? 'Enabled  •  ${entries!.length} rule${entries.length == 1 ? '' : 's'}'
          : 'Enabled  •  No rule';
      statusColor = hasEntries ? Colors.green.shade700 : Colors.orange.shade800;
    } else if (enabled == false) {
      statusText = hasEntries
          ? 'Disabled  •  ${entries!.length} saved rule${entries.length == 1 ? '' : 's'}'
          : 'Disabled  •  No rule';
      statusColor = hasEntries ? Colors.orange.shade800 : Colors.grey.shade700;
    } else {
      statusText = 'Status unavailable';
      statusColor = Colors.orange.shade800;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HuaweiDeviceAccessControlScreen(
            routerIp: widget.routerIp,
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          ),
        ),
      ).then((_) => _loadAccessControlSummary()),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _accessControlError != null
                ? Colors.orange.shade200
                : hasEntries && enabled == true
                    ? Colors.green.shade200
                    : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFB00020).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.devices_rounded, color: Color(0xFFB00020)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Device Access Control', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (!_loadingAccessSummary && _accessControlError == null) ...[
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          statusText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Manage device access and access-control rules',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  if (_accessControlError != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Tap to open and diagnose.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
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
        _buildAccessControlSummary(),
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
        actions: [
          if (_loggedIn)
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout_rounded),
              onPressed: _logout,
            ),
        ],
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
                const SizedBox(height: 12),
                _buildWanCard(),
                const SizedBox(height: 16),
                _buildFeatureSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
