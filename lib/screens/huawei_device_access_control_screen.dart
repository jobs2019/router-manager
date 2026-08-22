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
  int? _sidLength;
  int? _tokenLength;
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
        _sidLength = status.sidLength;
        _tokenLength = status.tokenLength;
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
    });

    try {
      final status = await _service.setEnabled(value);

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
        _entryMessage =
            'Default rule submitted: Priority 1, WAN / All, HTTP, Permit. '
            'Detected ${entries.length} Access Control entr${entries.length == 1 ? 'y' : 'ies'}.';
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
            ? 'Deleted $deleted Access Control entr${deleted == 1 ? 'y' : 'ies'}. Huawei reports the list is now empty.'
            : 'Delete completed, but Huawei still reports ${remaining.length} entr${remaining.length == 1 ? 'y' : 'ies'}.';
      });
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
    final hasEntries = _entryIndices.isNotEmpty;

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
                            onChanged: enabled == null || _saving
                                ? null
                                : _toggle,
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
                      'Access Control Entries',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasEntries
                          ? 'Huawei reports ${_entryIndices.length} existing entr${_entryIndices.length == 1 ? 'y' : 'ies'} (indexes: ${_entryIndices.join(', ')}).'
                          : 'Huawei reports no existing Access Control entries.',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                enabled == true && !_saving ? _newEntry : null,
                            icon: const Icon(Icons.add),
                            label: const Text('New'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: hasEntries && !_saving
                                ? _deleteAllEntries
                                : null,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete All'),
                          ),
                        ),
                      ],
                    ),
                    if (_entryMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _entryMessage!,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _row(
                      'SID',
                      _sidLength == null
                          ? '--'
                          : 'obtained ($_sidLength chars)',
                    ),
                    _row(
                      'onttoken',
                      _tokenLength == null
                          ? '--'
                          : 'fresh ($_tokenLength chars)',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SID and token values are never shown in the app.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
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
                  'Access Control state is read from Huawei and verified again after every ON/OFF change. '
                  'Existing entries can now be detected and deleted before creating the standard rule. '
                  'The Delete request follows the confirmed EG8145V5 del.cgi endpoint and token field.',
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
