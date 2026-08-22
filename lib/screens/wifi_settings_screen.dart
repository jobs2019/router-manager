import 'package:flutter/material.dart';

import '../services/se06_api.dart';

class WifiSettingsScreen extends StatefulWidget {
  final Se06Api api;

  const WifiSettingsScreen({
    super.key,
    required this.api,
  });

  @override
  State<WifiSettingsScreen> createState() =>
      _WifiSettingsScreenState();
}

class _WifiSettingsScreenState
    extends State<WifiSettingsScreen> {
  final TextEditingController _ssidController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;

  String _encryption = 'Unknown';

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWifi();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadWifi() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.api.getWifi();

      final result = data['result'];

      if (result is! Map) {
        throw Exception(
          'Invalid Wi-Fi response from router.',
        );
      }

      final master = result['master'];

      if (master is! Map) {
        throw Exception(
          'Router did not return the main Wi-Fi configuration.',
        );
      }

      final ssid = master['ssid'];

      final encryption = master['encryption'];

      if (ssid == null) {
        throw Exception(
          'Router did not return the Wi-Fi SSID.',
        );
      }

      if (!mounted) return;

      setState(() {
        _ssidController.text = ssid.toString();

        _encryption =
            encryption?.toString() ?? 'Unknown';

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveWifi() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    if (ssid.isEmpty) {
      _showMessage(
        'Wi-Fi name cannot be empty.',
      );
      return;
    }

    if (password.isEmpty) {
      _showMessage(
        'Please enter the Wi-Fi password.',
      );
      return;
    }

    if (password.length < 8) {
      _showMessage(
        'Wi-Fi password must be at least 8 characters.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      final response = await widget.api.setWifi(
        ssid: ssid,
        password: password,
      );

      final errcode = response['errcode'];

      if (errcode != 0) {
        throw Exception(
          'Router returned error code: $errcode',
        );
      }

      if (!mounted) return;

      setState(() {
        _saving = false;
        _passwordController.clear();
      });

      await _showSavedDialog();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        'Failed to save Wi-Fi settings: $e',
      );
    }
  }

  Future<void> _showSavedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Wi-Fi Settings Saved',
          ),
          content: const Text(
            'The router accepted the new Wi-Fi settings.\n\n'
            'If you changed the Wi-Fi name or password, '
            'your phone may disconnect from the router. '
            'Reconnect using the new credentials.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _encryptionLabel() {
    switch (_encryption) {
      case 'mixed-psk':
        return 'WPA/WPA2 Personal';

      case 'psk2':
        return 'WPA2 Personal';

      case 'psk':
        return 'WPA Personal';

      case 'none':
        return 'Open / No Password';

      default:
        return _encryption;
    }
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Reading Wi-Fi settings...',
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),

            const SizedBox(height: 16),

            const Text(
              'Unable to read Wi-Fi settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _loadWifi,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Main Wi-Fi',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Change the Wi-Fi name and password '
          'of your SE06 Pro.',
          style: TextStyle(
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 24),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wi-Fi Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _ssidController,
                  enabled: !_saving,
                  textInputAction:
                      TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'SSID',
                    hintText: 'Enter Wi-Fi name',
                    prefixIcon: Icon(Icons.wifi),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Security',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.security,
                    ),
                  ),
                  child: Text(
                    _encryptionLabel(),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'New Wi-Fi Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _passwordController,
                  enabled: !_saving,
                  obscureText: _obscurePassword,
                  textInputAction:
                      TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText:
                        'Enter new Wi-Fi password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                              !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'For security, the current Wi-Fi password '
                  'is not displayed. Enter the password you '
                  'want to use.',
                  style: TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _saving
                ? null
                : _saveWifi,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.save,
                  ),
            label: Text(
              _saving
                  ? 'Saving...'
                  : 'Save Changes',
            ),
          ),
        ),

        const SizedBox(height: 16),

        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Changing the Wi-Fi name or password '
                    'may disconnect your phone from the '
                    'router. Reconnect using the new '
                    'credentials after saving.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wi-Fi Settings',
        ),
        actions: [
          IconButton(
            onPressed: _loading || _saving
                ? null
                : _loadWifi,
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildSettings(),
    );
  }
}