import 'package:flutter/material.dart';

import '../models/huawei_wifi_settings.dart';
import '../services/huawei_api.dart';

class HuaweiWifiSettingsScreen extends StatefulWidget {
  final HuaweiApi api;

  const HuaweiWifiSettingsScreen({
    super.key,
    required this.api,
  });

  @override
  State<HuaweiWifiSettingsScreen> createState() =>
      _HuaweiWifiSettingsScreenState();
}

class _HuaweiWifiSettingsScreenState
    extends State<HuaweiWifiSettingsScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _maxDevicesController = TextEditingController();
  final _groupRekeyController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  bool _broadcast = true;
  bool _wmm = true;
  bool _wps = false;

  String _authenticationMode = 'PSKAuthentication';
  String _encryptionMode = 'TKIPandAESEncryption';

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
    _passwordController.dispose();
    _maxDevicesController.dispose();
    _groupRekeyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final settings = await widget.api.get2GWifiSettings();
      _applySettings(settings);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _cleanError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applySettings(HuaweiWifiSettings settings) {
    _enabled = settings.enabled;
    _broadcast = settings.broadcastSsid;
    _wmm = settings.wmmEnabled;
    _wps = settings.wpsEnabled;
    _authenticationMode = settings.authenticationMode;
    _encryptionMode = settings.encryptionMode;
    _ssidController.text = settings.ssid;
    _maxDevicesController.text = settings.maxAssociateNum.toString();
    _groupRekeyController.text = settings.groupRekey.toString();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final ssid = _ssidController.text.trim();
    final maxDevices = int.tryParse(_maxDevicesController.text.trim());
    final groupRekey = int.tryParse(_groupRekeyController.text.trim());

    if (ssid.isEmpty || ssid.length > 32) {
      _showError('Wi-Fi name must contain 1–32 characters.');
      return;
    }

    if (maxDevices == null || maxDevices < 1 || maxDevices > 32) {
      _showError('Maximum devices must be between 1 and 32.');
      return;
    }

    if (groupRekey == null || groupRekey < 600 || groupRekey > 86400) {
      _showError('Group key interval must be between 600 and 86400 seconds.');
      return;
    }

    final password = _passwordController.text;
    if (password.isNotEmpty &&
        (password.length < 8 || password.length > 63)) {
      _showError('Wi-Fi password must contain 8–63 characters.');
      return;
    }

    final settings = HuaweiWifiSettings(
      enabled: _enabled,
      ssid: ssid,
      broadcastSsid: _broadcast,
      wmmEnabled: _wmm,
      maxAssociateNum: maxDevices,
      authenticationMode: _authenticationMode,
      encryptionMode: _encryptionMode,
      groupRekey: groupRekey,
      wpsEnabled: _wps,
    );

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      await widget.api.update2GWifiSettings(
        settings: settings,
        password: password.isEmpty ? null : password,
      );

      if (!mounted) return;

      _passwordController.clear();
      setState(() {
        _success = '2.4 GHz Wi-Fi settings saved successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFB00020),
          width: 1.5,
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text(
          '2.4 GHz Wi-Fi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
                          Icon(
                            Icons.wifi_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '2.4 GHz Wi-Fi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Basic wireless settings',
                                  style: TextStyle(color: Colors.white70),
                                ),
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
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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
                            Expanded(
                              child: Text(
                                _success!,
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Network',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _switchTile(
                            title: 'Wi-Fi Enabled',
                            subtitle: _enabled
                                ? '2.4 GHz wireless network is active.'
                                : '2.4 GHz wireless network is disabled.',
                            value: _enabled,
                            onChanged: (value) {
                              setState(() => _enabled = value);
                            },
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _ssidController,
                            maxLength: 32,
                            decoration: _decoration('Wi-Fi Name (SSID)'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            maxLength: 63,
                            decoration: _decoration(
                              'New Wi-Fi Password',
                              hint: 'Leave blank to keep current password',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Password must be 8–63 characters. The current password is never displayed.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wireless Options',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _switchTile(
                            title: 'Broadcast SSID',
                            subtitle: _broadcast
                                ? 'Nearby devices can see this network.'
                                : 'The network name is hidden.',
                            value: _broadcast,
                            onChanged: (value) {
                              setState(() => _broadcast = value);
                            },
                          ),
                          _switchTile(
                            title: 'WMM',
                            subtitle: 'Wireless multimedia quality of service.',
                            value: _wmm,
                            onChanged: (value) {
                              setState(() => _wmm = value);
                            },
                          ),
                          _switchTile(
                            title: 'WPS',
                            subtitle: _wps
                                ? 'Push-button WPS is enabled.'
                                : 'WPS is disabled.',
                            value: _wps,
                            onChanged: (value) {
                              setState(() => _wps = value);
                            },
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _maxDevicesController,
                            keyboardType: TextInputType.number,
                            decoration: _decoration(
                              'Maximum Connected Devices',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Security',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _authenticationMode,
                            decoration: _decoration('Authentication'),
                            items: const [
                              DropdownMenuItem(
                                value: 'PSKAuthentication',
                                child: Text('WPA/WPA2 Personal'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _authenticationMode = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _encryptionMode,
                            decoration: _decoration('Encryption'),
                            items: const [
                              DropdownMenuItem(
                                value: 'TKIPandAESEncryption',
                                child: Text('TKIP & AES'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _encryptionMode = value);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _groupRekeyController,
                            keyboardType: TextInputType.number,
                            decoration: _decoration(
                              'Group Key Regeneration Interval (seconds)',
                            ),
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
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _saving ? 'Saving...' : 'Save Wi-Fi Settings',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saving Wi-Fi settings may temporarily disconnect devices using this network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
