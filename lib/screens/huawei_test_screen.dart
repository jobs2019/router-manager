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

  // Huawei login
  final TextEditingController _usernameController =
      TextEditingController(text: 'telecomadmin');

  final TextEditingController _passwordController =
      TextEditingController(text: 'admintelecom');

  // Add PPPoE
  final TextEditingController _pppoeUsernameController =
      TextEditingController();

  final TextEditingController _pppoePasswordController =
      TextEditingController(text: 'admin123');

  final TextEditingController _vlanController =
      TextEditingController();

  bool _loading = false;
  bool _loggedIn = false;
  bool _loadingWan = false;
  bool _addingWan = false;

  bool _enableVlan = false;

  String? _error;
  String? _successMessage;

  List<Map<String, String>>? _wanData;

  final Set<String> _selectedLan = <String>{};

  final Set<String> _selectedSsid = <String>{'SSID1'};

  @override
  void initState() {
    super.initState();

    _api = HuaweiApi(
      baseUrl: 'http://${widget.routerIp}',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _pppoeUsernameController.dispose();
    _pppoePasswordController.dispose();
    _vlanController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _loginHuawei() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _successMessage = null;
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

  // ============================================================
  // WAN INFORMATION
  // ============================================================

  Future<void> _loadWan() async {
    if (!_loggedIn) {
      return;
    }

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

  // ============================================================
  // ADD PPPoE WAN
  // ============================================================

  Future<void> _addPppoeWan() async {
    FocusScope.of(context).unfocus();

    final username =
        _pppoeUsernameController.text.trim();

    final password =
        _pppoePasswordController.text;

    if (username.isEmpty) {
      _showError(
        'Please enter the PPPoE username.',
      );
      return;
    }

    if (password.isEmpty) {
      _showError(
        'Please enter the PPPoE password.',
      );
      return;
    }

    int vlanId = 0;

    if (_enableVlan) {
      vlanId =
          int.tryParse(
                _vlanController.text.trim(),
              ) ??
              0;

      if (vlanId < 1 || vlanId > 4094) {
        _showError(
          'Please enter a valid VLAN ID from 1 to 4094.',
        );
        return;
      }
    }

    setState(() {
      _addingWan = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await _api.addPppoeWan(
        username: username,
        password: password,
        enableVlan: _enableVlan,
        vlanId: vlanId,
        priority: 0,
        mtu: 1492,
        lanBindings: _selectedLan.toList(),
        ssidBindings: _selectedSsid.toList(),
      );

      if (!mounted) return;

      setState(() {
        _successMessage =
            'PPPoE WAN was created successfully.';
      });

      // Give Huawei a moment to create the WAN.
      await Future<void>.delayed(
        const Duration(milliseconds: 1000),
      );

      await _loadWan();

      if (!mounted) return;

      _showSuccess(
        'PPPoE WAN created successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _cleanError(e);
      });
    }

    if (!mounted) return;

    setState(() {
      _addingWan = false;
    });
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String? value,
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
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value == null || value.isEmpty
                  ? '--'
                  : value,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WAN CARD
  // ============================================================

  Widget _buildWanCard() {
    if (_loadingWan) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(),
          ),
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'WAN Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            ..._wanData!.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final wan = entry.value;

                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (index > 0)
                      const Divider(
                        height: 30,
                      ),

                    Text(
                      wan['wanName'] ?? '--',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    _infoRow(
                      'Status',
                      wan['status'],
                    ),

                    _infoRow(
                      'IP Address',
                      wan['ipAddress'],
                    ),

                    _infoRow(
                      'VLAN ID',
                      wan['vlanId'],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _loadingWan
                        ? null
                        : _loadWan,
                icon: const Icon(
                  Icons.refresh,
                ),
                label: const Text(
                  'Refresh WAN Information',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ADD PPPoE CARD
  // ============================================================

  Widget _buildAddPppoeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Add PPPoE WAN',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Create a new PPPoE WAN connection.',
            ),

            const SizedBox(height: 20),

            // PPPoE USERNAME
            TextField(
              controller:
                  _pppoeUsernameController,
              decoration:
                  const InputDecoration(
                labelText: 'PPPoE Username',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // PPPoE PASSWORD
            TextField(
              controller:
                  _pppoePasswordController,
              obscureText: false,
              decoration:
                  const InputDecoration(
                labelText: 'PPPoE Password',
                border: OutlineInputBorder(),
                helperText:
                    'Default: admin123',
              ),
            ),

            const SizedBox(height: 12),

            // VLAN ENABLE
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enable VLAN',
              ),
              value: _enableVlan,
              onChanged: (value) {
                setState(() {
                  _enableVlan =
                      value ?? false;
                });
              },
            ),

            // VLAN ID
            if (_enableVlan)
              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                child: TextField(
                  controller:
                      _vlanController,
                  keyboardType:
                      TextInputType.number,
                  decoration:
                      const InputDecoration(
                    labelText: 'VLAN ID',
                    hintText: '1 - 4094',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            const Text(
              'Binding Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // LAN
            const Text(
              'LAN',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            Wrap(
              spacing: 4,
              children: [
                _bindingCheckbox(
                  'LAN1',
                  _selectedLan.contains('LAN1'),
                  (value) {
                    _toggleBinding(
                      _selectedLan,
                      'LAN1',
                      value,
                    );
                  },
                ),
                _bindingCheckbox(
                  'LAN2',
                  _selectedLan.contains('LAN2'),
                  (value) {
                    _toggleBinding(
                      _selectedLan,
                      'LAN2',
                      value,
                    );
                  },
                ),
                _bindingCheckbox(
                  'LAN3',
                  _selectedLan.contains('LAN3'),
                  (value) {
                    _toggleBinding(
                      _selectedLan,
                      'LAN3',
                      value,
                    );
                  },
                ),
                _bindingCheckbox(
                  'LAN4',
                  _selectedLan.contains('LAN4'),
                  (value) {
                    _toggleBinding(
                      _selectedLan,
                      'LAN4',
                      value,
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // SSID
            const Text(
              'SSID',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: List.generate(
                8,
                (index) {
                  final ssid =
                      'SSID${index + 1}';

                  return _bindingCheckbox(
                    ssid,
                    _selectedSsid.contains(ssid),
                    (value) {
                      _toggleBinding(
                        _selectedSsid,
                        ssid,
                        value,
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // DEFAULTS
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(8),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
              child: const Text(
                'Defaults: IPv4 • Route WAN • '
                'INTERNET • 802.1p 0 • '
                'NAT Enabled • Always On • '
                'MTU 1492',
              ),
            ),

            const SizedBox(height: 16),

            // CREATE BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed:
                    _addingWan
                        ? null
                        : _addPppoeWan,
                icon: _addingWan
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.add,
                      ),
                label: Text(
                  _addingWan
                      ? 'Creating WAN...'
                      : 'Create PPPoE WAN',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bindingCheckbox(
    String label,
    bool selected,
    ValueChanged<bool?> onChanged,
  ) {
    return SizedBox(
      width: 90,
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: selected,
        onChanged: onChanged,
        controlAffinity:
            ListTileControlAffinity.leading,
      ),
    );
  }

  void _toggleBinding(
    Set<String> set,
    String value,
    bool? checked,
  ) {
    setState(() {
      if (checked == true) {
        set.add(value);
      } else {
        set.remove(value);
      }
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Huawei EG8145V5',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          Text(
            'Router: ${widget.routerIp}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // ====================================================
          // HUAWEI LOGIN
          // ====================================================

          TextField(
            controller:
                _usernameController,
            decoration:
                const InputDecoration(
              labelText:
                  'Huawei Username',
              border:
                  OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller:
                _passwordController,
            obscureText: true,
            decoration:
                const InputDecoration(
              labelText:
                  'Huawei Password',
              border:
                  OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed:
                  _loading
                      ? null
                      : _loginHuawei,
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
                      'Login to Huawei',
                    ),
            ),
          ),

          // ====================================================
          // ERROR
          // ====================================================

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

          // ====================================================
          // SUCCESS
          // ====================================================

          if (_successMessage != null) ...[
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Text(
                  _successMessage!,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],

          // ====================================================
          // LOGGED IN CONTENT
          // ====================================================

          if (_loggedIn) ...[
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Huawei login successful',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // WAN INFORMATION
            _buildWanCard(),

            const SizedBox(height: 16),

            // ADD PPPoE
            _buildAddPppoeCard(),
          ],
        ],
      ),
    );
  }
}