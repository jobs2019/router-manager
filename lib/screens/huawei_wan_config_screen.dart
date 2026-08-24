import 'package:flutter/material.dart';

import '../models/huawei_wan_configuration.dart';
import '../services/huawei_wan_api.dart';

class HuaweiWanConfigScreen extends StatefulWidget {
  const HuaweiWanConfigScreen({
    super.key,
    required this.routerIp,
    required this.username,
    required this.password,
  });

  final String routerIp;
  final String username;
  final String password;

  @override
  State<HuaweiWanConfigScreen> createState() => _HuaweiWanConfigScreenState();
}

class _HuaweiWanConfigScreenState extends State<HuaweiWanConfigScreen> {
  late final HuaweiWanApi _api;
  bool _loading = true;
  String? _error;
  List<HuaweiWanConfiguration> _wans = const [];

  @override
  void initState() {
    super.initState();
    _api = HuaweiWanApi(baseUrl: 'http://${widget.routerIp}');
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _api.login(username: widget.username, password: widget.password);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _loading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getWanConfigurations();
      if (!mounted) return;
      setState(() {
        _wans = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _loading = false;
      });
    }
  }

  String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');

  Future<void> _addWan() async {
    final result = await showDialog<_WanFormResult>(
      context: context,
      builder: (_) => const _WanFormDialog(),
    );
    if (result == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.addPppoeWan(
        vlanId: result.vlanId,
        username: result.username,
        password: result.password,
        bindings: result.bindings,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WAN configuration added.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _loading = false;
      });
    }
  }

  Future<void> _editWan(HuaweiWanConfiguration wan) async {
    final result = await showDialog<_WanFormResult>(
      context: context,
      builder: (_) => _WanFormDialog(existing: wan),
    );
    if (result == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final password = result.password.isEmpty ? wan.password : result.password;
      await _api.editPppoeWan(
        domain: wan.domain,
        vlanId: result.vlanId,
        username: result.username,
        password: password,
        bindings: result.bindings,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WAN configuration updated.')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _loading = false;
      });
    }
  }

  Widget _wanCard(HuaweiWanConfiguration wan) {
    final connected = wan.status.toLowerCase() == 'connected';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    wan.wanName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: connected
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    wan.status.isEmpty ? '--' : wan.status,
                    style: TextStyle(
                      color: connected ? Colors.green.shade700 : Colors.orange.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow('VLAN ID', wan.vlanId.isEmpty ? '-' : wan.vlanId),
            _infoRow('Username', wan.username),
            _infoRow('Binding', wan.bindings.isEmpty ? 'None' : wan.bindings.join(', ')),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _editWan(wan),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('WAN Configuration', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addWan,
        icon: const Icon(Icons.add),
        label: const Text('Add WAN'),
      ),
      body: SafeArea(
        child: _loading && _wans.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    if (_error != null)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (_error != null) const SizedBox(height: 10),
                    if (_wans.isEmpty && _error == null)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No PPPoE WAN configurations found.')),
                      ),
                    ..._wans.map(_wanCard),
                  ],
                ),
              ),
      ),
    );
  }
}

class _WanFormResult {
  const _WanFormResult({
    required this.vlanId,
    required this.username,
    required this.password,
    required this.bindings,
  });

  final int vlanId;
  final String username;
  final String password;
  final List<String> bindings;
}

class _WanFormDialog extends StatefulWidget {
  const _WanFormDialog({this.existing});

  final HuaweiWanConfiguration? existing;

  @override
  State<_WanFormDialog> createState() => _WanFormDialogState();
}

class _WanFormDialogState extends State<_WanFormDialog> {
  late final TextEditingController _vlanController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final Set<String> _bindings;
  bool _obscurePassword = true;

  static const _lanOptions = ['LAN1', 'LAN2', 'LAN3', 'LAN4'];
  static const _ssidOptions = ['SSID1', 'SSID2', 'SSID3', 'SSID4', 'SSID5', 'SSID6', 'SSID7', 'SSID8'];

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _vlanController = TextEditingController(text: existing?.vlanId == '-' ? '' : existing?.vlanId ?? '');
    _usernameController = TextEditingController(text: existing?.username ?? '');
    _passwordController = TextEditingController();
    _bindings = {...?existing?.bindings};
  }

  @override
  void dispose() {
    _vlanController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final vlan = int.tryParse(_vlanController.text.trim());
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (vlan == null || vlan < 1 || vlan > 4094) {
      _showError('VLAN ID must be between 1 and 4094.');
      return;
    }
    if (username.isEmpty) {
      _showError('PPPoE username is required.');
      return;
    }
    if (!_editing && password.isEmpty) {
      _showError('PPPoE password is required.');
      return;
    }
    Navigator.of(context).pop(
      _WanFormResult(
        vlanId: vlan,
        username: username,
        password: password,
        bindings: _orderedBindings(),
      ),
    );
  }

  List<String> _orderedBindings() {
    return [
      ..._lanOptions.where(_bindings.contains),
      ..._ssidOptions.where(_bindings.contains),
    ];
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _bindingSection(String title, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 2,
          runSpacing: 0,
          children: options.map((value) {
            return SizedBox(
              width: 96,
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(value, style: const TextStyle(fontSize: 13)),
                value: _bindings.contains(value),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _bindings.add(value);
                    } else {
                      _bindings.remove(value);
                    }
                  });
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit PPPoE WAN' : 'Add PPPoE WAN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _vlanController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'VLAN ID',
                hintText: '1–4094',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'PPPoE Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'PPPoE Password',
                hintText: _editing ? 'Leave blank to keep current password' : null,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Binding Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _bindingSection('LAN', _lanOptions),
            const Divider(height: 18),
            _bindingSection('Wi-Fi', _ssidOptions),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(_editing ? 'Save' : 'Add')),
      ],
    );
  }
}
