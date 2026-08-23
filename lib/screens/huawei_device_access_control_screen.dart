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
  String? _entryMessage;
  List<int> _entryIndices = const [];

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
      final entries = await _service.getEntryIndices();

      if (!mounted) return;

      setState(() {
        _enabled = status.enabled;
        _entryIndices = entries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving || _enabled == null) return;

    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(widget.routerIp),
          content: const Text(
            'The connection may be interrupted. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _entryMessage = null;
    });

    try {
      final status = await _service.setEnabled(value);

      if (!mounted) return;

      setState(() => _enabled = status.enabled);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  HuaweiAccessControlRule _defaultNewRule() {
    return const HuaweiAccessControlRule(
      priority: '1',
      srcPortName: 'ALL',
      servicePort: 'HTTP',
      srcPortType: '2',
      srcIp: '',
      mode: '0',
      serviceProto: '',
      serviceProtoPort: '',
    );
  }

  Future<bool> _confirmHuaweiOperation(String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(widget.routerIp),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _newEntry() async {
    if (_saving || _enabled != true) return;

    if (_entryIndices.isNotEmpty) {
      _showMessage(
        'Delete the existing Access Control entry first, then create the new rule.',
      );
      return;
    }

    final rule = _defaultNewRule();

    setState(() {
      _saving = true;
      _error = null;
      _entryMessage = null;
    });

    try {
      await _service.prepareAddEntry();

      if (!mounted) return;

      final confirmed = await _confirmHuaweiOperation(
        'The connection may be interrupted. Continue?',
      );

      if (confirmed != true) return;

      await _service.addEntry(rule);

      final entries = await _service.getEntryIndices();

      if (!mounted) return;
      setState(() {
        _entryIndices = entries;
        _entryMessage = entries.isEmpty
            ? 'Huawei did not report the new rule after saving.'
            : 'Default rule created successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAllEntries() async {
    if (_saving || _entryIndices.isEmpty) return;

    final count = _entryIndices.length;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete all entries?'),
        content: Text(
          'This will delete all $count Access Control entr${count == 1 ? 'y' : 'ies'} '
          'currently reported by the Huawei router. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _error = null;
      _entryMessage = null;
    });

    try {
      final deleted = await _service.deleteAllEntries();
      final remaining = await _service.getEntryIndices();

      if (!mounted) return;
      setState(() {
        _entryIndices = remaining;
        _entryMessage = remaining.isEmpty
            ? 'Deleted $deleted Access Control entr${deleted == 1 ? 'y' : 'ies'}. The router list is now empty.'
            : 'Delete completed, but Huawei still reports ${remaining.length} entr${remaining.length == 1 ? 'y' : 'ies'}.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final hasEntries = _entryIndices.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Device Access Control',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildRouterCard(enabled),
            const SizedBox(height: 14),
            _buildRulesCard(enabled, hasEntries),
            if (_entryMessage != null) ...[
              const SizedBox(height: 12),
              _buildMessageCard(_entryMessage!, isError: false),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _buildMessageCard(_error!, isError: true),
            ],
            const SizedBox(height: 14),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouterCard(bool? enabled) {
    final isEnabled = enabled == true;

    return Card(
      elevation: 0,
      color: const Color(0xFFF4EFFA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.router_rounded, size: 27),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Huawei EG8145V5',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.routerIp,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                if (!_loading)
                  _statusBadge(
                    label: isEnabled ? 'ON' : 'OFF',
                    active: isEnabled,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LinearProgressIndicator(),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text('Controls the Huawei Access Control service.'),
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
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRulesCard(bool? enabled, bool hasEntries) {
    final canCreate = enabled == true && !hasEntries && !_saving;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Access Control Rule',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _statusBadge(
                  label: hasEntries ? '1 RULE' : 'EMPTY',
                  active: hasEntries,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasEntries
                  ? 'Huawei reports ${_entryIndices.length} existing rule${_entryIndices.length == 1 ? '' : 's'}.'
                  : 'No Access Control rule is currently configured.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (hasEntries) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rule_rounded, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Huawei rule index: ${_entryIndices.join(', ')}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canCreate ? _newEntry : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasEntries && !_saving
                        ? _deleteAllEntries
                        : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete All'),
                  ),
                ),
              ],
            ),
            if (hasEntries && enabled != true) ...[
              const SizedBox(height: 10),
              Text(
                'Access Control is OFF, but the router still has a saved rule. Delete it here before creating a new rule.',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (hasEntries) ...[
              const SizedBox(height: 10),
              Text(
                'Delete the existing rule before creating another one.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ] else if (enabled != true && !_loading) ...[
              const SizedBox(height: 10),
              Text(
                'Turn Access Control ON before creating the default rule.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(String message, {required bool isError}) {
    final textColor = isError ? Colors.red.shade700 : Colors.green.shade800;
    final background = isError
        ? Colors.red.withValues(alpha: 0.06)
        : Colors.green.withValues(alpha: 0.06);

    return Card(
      elevation: 0,
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: textColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      color: Colors.blue.withValues(alpha: 0.055),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Changes are read back from the Huawei router after saving so the app does not report success when the router rejects the request.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge({required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: active ? Colors.green.shade700 : Colors.grey.shade700,
        ),
      ),
    );
  }
}
