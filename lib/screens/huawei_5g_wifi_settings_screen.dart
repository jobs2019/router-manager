import 'package:flutter/material.dart';

import '../models/huawei_simple_wifi_settings.dart';
import '../services/huawei_api.dart';

class Huawei5GWifiSettingsScreen extends StatefulWidget {
  final HuaweiApi api;

  const Huawei5GWifiSettingsScreen({
    super.key,
    required this.api,
  });

  @override
  State<Huawei5GWifiSettingsScreen> createState() => _Huawei5GWifiSettingsScreenState();
}

class _Huawei5GWifiSettingsScreenState extends State<Huawei5GWifiSettingsScreen> {
  final _ssidController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _maxDevicesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  bool _broadcastSsid = true;
  bool _wmmEnabled = true;
  bool _staIsolation = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _newPasswordController.dispose();
    _maxDevicesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final settings = await widget.api.getSimpleWifiSettings();
      _apply(settings.band5G);
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(HuaweiSimpleWifiBandSettings settings) {
    _enabled = settings.enabled;
    _broadcastSsid = settings.broadcastSsid;
    _wmmEnabled = settings.wmmEnabled;
    _staIsolation = settings.staIsolation;
    _ssidController.text = settings.ssid;
    _maxDevicesController.text = settings.maxAssociateNum.toString();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final ssid = _ssidController.text.trim();
    final password = _newPasswordController.text.trim();
    final maxDevices = int.tryParse(_maxDevicesController.text.trim());

    if (ssid.isEmpty || ssid.length > 32) {
      _showError('Wi-Fi name must contain 1–32 characters.');
      return;
    }
    if (maxDevices == null || maxDevices < 1 || maxDevices > 32) {
      _showError('Maximum devices must be between 1 and 32.');
      return;
    }
    if (password.isNotEmpty && (password.length < 8 || password.length > 63)) {
      _showError('New Wi-Fi password must contain 8–63 characters.');
      return;
    }

    final settings = HuaweiSimpleWifiBandSettings(
      enabled: _enabled,
      ssid: ssid,
      broadcastSsid: _broadcastSsid,
      wmmEnabled: _wmmEnabled,
      staIsolation: _staIsolation,
      maxAssociateNum: maxDevices,
    );

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      await widget.api.update5GWifiSettings(
        settings: settings,
        password: password.isEmpty ? null : password,
      );

      if (!mounted) return;
      _newPasswordController.clear();
      setState(() {
        _success = password.isEmpty
            ? '5 GHz Wi-Fi settings saved successfully.'
            : '5 GHz Wi-Fi password changed successfully.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');

  void _showError(String message) {
    setState(() {
      _error = message;
      _success = null;
    });
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB00020), width: 1.5),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('5 GHz Wi-Fi', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB00020), Color(0xFFE53935)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_rounded, color: Colors.white, size: 34),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('5 GHz Wi-Fi', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text('High-speed wireless settings', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      _card(
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_success != null) ...[
                      _card(
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_success!, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Network', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Wi-Fi Enabled', style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(_enabled ? '5 GHz wireless network is active.' : '5 GHz wireless network is disabled.'),
                            value: _enabled,
                            onChanged: (value) => setState(() => _enabled = value),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _ssidController,
                            maxLength: 32,
                            decoration: _decoration('Wi-Fi Name (SSID)'),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _newPasswordController,
                            obscureText: false,
                            maxLength: 63,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: _decoration('New Wi-Fi Password', hint: 'Leave blank to keep current password'),
                          ),
                          Text(
                            'The existing password is not read. Enter a new password only when you want to change it.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Security', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: 'PSKAuthentication',
                            decoration: _decoration('Authentication'),
                            items: const [DropdownMenuItem(value: 'PSKAuthentication', child: Text('WPA/WPA2 Personal'))],
                            onChanged: null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: 'TKIPandAESEncryption',
                            decoration: _decoration('Encryption'),
                            items: const [DropdownMenuItem(value: 'TKIPandAESEncryption', child: Text('TKIP & AES'))],
                            onChanged: null,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _maxDevicesController,
                            keyboardType: TextInputType.number,
                            decoration: _decoration('Maximum Connected Devices'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'Saving...' : 'Save 5 GHz Wi-Fi Settings'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saving Wi-Fi settings may temporarily disconnect devices using this network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
