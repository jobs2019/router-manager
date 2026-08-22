import 'package:flutter/material.dart';

import '../services/huawei_api.dart';

class HuaweiWifiSettingsScreen extends StatefulWidget {
  final HuaweiApi api;

  const HuaweiWifiSettingsScreen({
    super.key,
    required this.api,
  });

  @override
  State<HuaweiWifiSettingsScreen> createState() => _HuaweiWifiSettingsScreenState();
}

class _HuaweiWifiSettingsScreenState extends State<HuaweiWifiSettingsScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      // Keep the existing parser first. If it cannot find WlanWifiArr,
      // read the current SSID directly from the y.SSID field on the same
      // WlanBasic.asp?2G page. The proven write request is untouched.
      try {
        final settings = await widget.api.get2GWifiSettings();
        if (!mounted) return;
        _ssidController.text = settings.ssid;
      } catch (_) {
        final page = await widget.api.getPage('/html/amp/wlanbasic/WlanBasic.asp?2G');
        final ssid = _extractCurrentSsid(page);
        if (ssid == null || ssid.isEmpty) {
          throw Exception('Huawei did not expose the current 2.4 GHz Wi-Fi name.');
        }
        if (!mounted) return;
        _ssidController.text = ssid;
      }
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _extractCurrentSsid(String body) {
    final nameMarker = 'name="y.SSID"';
    final nameIndex = body.indexOf(nameMarker);
    if (nameIndex < 0) return null;

    final inputStart = body.lastIndexOf('<input', nameIndex);
    final inputEnd = body.indexOf('>', nameIndex);
    if (inputStart < 0 || inputEnd < 0 || inputEnd <= inputStart) return null;

    final input = body.substring(inputStart, inputEnd + 1);
    final valueMarker = 'value="';
    final valueIndex = input.indexOf(valueMarker);
    if (valueIndex < 0) return null;

    final valueStart = valueIndex + valueMarker.length;
    final valueEnd = input.indexOf('"', valueStart);
    if (valueEnd < 0) return null;

    final value = input.substring(valueStart, valueEnd).trim();
    return value.isEmpty ? null : _decodeHtml(value);
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();

    if (ssid.isEmpty || ssid.length > 32) {
      _showError('Wi-Fi name must contain 1–32 characters.');
      return;
    }
    if (password.length < 8 || password.length > 63) {
      _showError('Wi-Fi password must contain 8–63 characters.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      await widget.api.update2GWifiNameAndPassword(
        ssid: ssid,
        password: password,
      );

      if (!mounted) return;
      _passwordController.clear();
      setState(() {
        _success = '2.4 GHz Wi-Fi name and password were applied successfully.';
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
        title: const Text('2.4 GHz Wi-Fi', style: TextStyle(fontWeight: FontWeight.w700)),
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
                                Text('2.4 GHz Wi-Fi', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text('Huawei Basic Network', style: TextStyle(color: Colors.white70)),
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
                          const Text('Wi-Fi Settings', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _ssidController,
                            maxLength: 32,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: _decoration('Wi-Fi Name (SSID)'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            obscureText: false,
                            maxLength: 63,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: _decoration('New Wi-Fi Password', hint: 'Enter 8–63 characters'),
                          ),
                          Text(
                            'The existing password is not read from telecomadmin. Enter a new password only when you want to change it.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
                        label: Text(_saving ? 'Saving...' : 'Save Wi-Fi Name & Password'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The Wi-Fi connection may temporarily disconnect while Huawei applies the change.',
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
