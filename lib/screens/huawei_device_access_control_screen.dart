import 'package:flutter/material.dart';

import '../services/huawei_device_access_control.dart';

class HuaweiDeviceAccessControlScreen extends StatefulWidget {
  const HuaweiDeviceAccessControlScreen({
    super.key,
    required this.routerIp,
    required this.username,
    required this.password,
  });

  final String routerIp;
  final String username;
  final String password;

  @override
  State<HuaweiDeviceAccessControlScreen> createState() =>
      _HuaweiDeviceAccessControlScreenState();
}

class _HuaweiDeviceAccessControlScreenState
    extends State<HuaweiDeviceAccessControlScreen> {
  late final HuaweiDeviceAccessControlService _service;

  bool _loading = true;
  bool _saving = false;
  bool? _enabled;
  String? _error;
  int? _sidLength;
  int? _tokenLength;

  @override
  void initState() {
    super.initState();
    _service = HuaweiDeviceAccessControlService(
      baseUrl: 'http://${widget.routerIp}',
    );
    _load();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.login(
        username: widget.username,
        password: widget.password,
      );
      final status = await _service.getStatus();
      if (!mounted) return;
      setState(() {
        _enabled = status.enabled;
        _sidLength = status.sidLength;
        _tokenLength = status.tokenLength;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;

    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disable access control?'),
          content: const Text(
            'This will disable the Huawei Device Access Control feature. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final status = await _service.setEnabled(value);
      if (!mounted) return;
      setState(() {
        _enabled = status.enabled;
        _sidLength = status.sidLength;
        _tokenLength = status.tokenLength;
      });
      if (_enabled != value) {
        setState(() {
          _error = 'Router did not report the requested state after saving.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Device Access Control',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      backgroundColor: const Color(0xFFF7F7F8),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Huawei EG8145V5',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.routerIp,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 18),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enable access control',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Uses the confirmed EG8145V5 AccessControl endpoint.',
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: enabled ?? false,
                            onChanged: enabled == null || _saving ? null : _toggle,
                          ),
                        ],
                      ),
                    if (_saving) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    _row('SID', _sidLength == null ? '--' : 'obtained ($_sidLength chars)'),
                    _row('onttoken', _tokenLength == null ? '--' : 'fresh ($_tokenLength chars)'),
                    const SizedBox(height: 6),
                    Text(
                      'SID and token values are never shown in the app.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              color: Colors.blue.withValues(alpha: 0.06),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Next: connected-device discovery and blacklist/whitelist management. '
                  'Those write endpoints will be added only after their exact EG8145V5 '
                  'browser requests are confirmed.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 95,
              child: Text(
                label,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
