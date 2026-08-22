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

  Future<void> _newEntry() async {
    if (_saving || _enabled != true) return;

    final rule = await showDialog<HuaweiAccessControlRule>(
      context: context,
      builder: (context) => const _NewAccessControlEntryDialog(),
    );

    if (rule == null || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
      _entryMessage = null;
    });

    try {
      // This request was observed immediately around the Huawei Apply
      // confirmation. We reproduce it before displaying the confirmation.
      await _service.prepareAddEntry();

      if (!mounted) return;

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

      await _service.addEntry(rule);

      if (!mounted) return;
      setState(() {
        _entryMessage =
            'Huawei accepted the Access Control add request. '
            'The entry-list response is not parsed yet, so the app will not '
            'claim that the rule is verified until that browser response is confirmed.';
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
                    const Text(
                      'Add a rule using the confirmed EG8145V5 add.cgi request.',
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: enabled == true && !_saving ? _newEntry : null,
                      icon: const Icon(Icons.add),
                      label: const Text('New'),
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
                  'The Add Entry request now follows the confirmed browser endpoint and field names. '
                  'Entry-list verification will be added only after its exact browser response is confirmed.',
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

class _NewAccessControlEntryDialog extends StatefulWidget {
  const _NewAccessControlEntryDialog();

  @override
  State<_NewAccessControlEntryDialog> createState() =>
      _NewAccessControlEntryDialogState();
}

class _NewAccessControlEntryDialogState
    extends State<_NewAccessControlEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priority = TextEditingController(text: '1');
  final _srcPortName = TextEditingController(text: 'ALL');
  final _servicePort = TextEditingController(text: 'HTTP');
  final _srcPortType = TextEditingController(text: '2');
  final _srcIp = TextEditingController();
  final _mode = TextEditingController(text: '0');
  final _serviceProto = TextEditingController();
  final _serviceProtoPort = TextEditingController();

  @override
  void dispose() {
    _priority.dispose();
    _srcPortName.dispose();
    _servicePort.dispose();
    _srcPortType.dispose();
    _srcIp.dispose();
    _mode.dispose();
    _serviceProto.dispose();
    _serviceProtoPort.dispose();
    super.dispose();
  }

  String _value(TextEditingController controller) => controller.text.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Access Control Entry'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_priority, 'Priority', required: true),
                _field(_srcPortName, 'Source Port Name', required: true),
                _field(_servicePort, 'Service Port', required: true),
                _field(_srcPortType, 'Source Port Type', required: true),
                _field(_srcIp, 'Source IP'),
                _field(_mode, 'Mode', required: true),
                _field(_serviceProto, 'Service Protocol'),
                _field(_serviceProtoPort, 'Service Protocol Port'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              HuaweiAccessControlRule(
                priority: _value(_priority),
                srcPortName: _value(_srcPortName),
                servicePort: _value(_servicePort),
                srcPortType: _value(_srcPortType),
                srcIp: _value(_srcIp),
                mode: _value(_mode),
                serviceProto: _value(_serviceProto),
                serviceProtoPort: _value(_serviceProtoPort),
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                ? 'Required'
                : null
            : null,
      ),
    );
  }
}
