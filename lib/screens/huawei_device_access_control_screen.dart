import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  State<HuaweiDeviceAccessControlScreen> createState() => _HuaweiDeviceAccessControlScreenState();
}

class _HuaweiDeviceAccessControlScreenState extends State<HuaweiDeviceAccessControlScreen> {
  late final String _baseUrl;

  String? _cookie;
  String? _token;
  bool _loading = true;
  bool _saving = false;
  bool _addingRule = false;
  bool _enabled = false;
  bool _stateKnown = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _baseUrl = 'http://${widget.routerIp}';
    _load();
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Accept': '*/*',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
    };
    if (_cookie != null) headers['Cookie'] = _cookie!;
    return headers;
  }

  String? _extractCookie(String value) {
    final first = value.split(';').first.trim();
    return first.isEmpty ? null : first;
  }

  Future<void> _login() async {
    final session = await http.get(
      Uri.parse('$_baseUrl/asp/GetRandCount.asp'),
      headers: _headers(),
    );
    if (session.statusCode != 200) {
      throw Exception('Huawei session request failed (HTTP ${session.statusCode}).');
    }

    _token = session.body.trim();
    final setCookie = session.headers['set-cookie'];
    if (setCookie != null) _cookie = _extractCookie(setCookie);
    if (_token == null || _token!.isEmpty) {
      throw Exception('Huawei did not return a login token.');
    }

    final loginBody = 'UserName=${Uri.encodeQueryComponent(widget.username)}&PassWord=${Uri.encodeQueryComponent(_base64(widget.password))}&Language=english&x.X_HW_Token=${Uri.encodeQueryComponent(_token!)}';

    final response = await http.post(
      Uri.parse('$_baseUrl/login.cgi'),
      headers: {
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': '$_baseUrl/login.asp',
        'Origin': _baseUrl,
      },
      body: loginBody,
    );

    if (response.statusCode != 200) {
      throw Exception('Huawei login failed (HTTP ${response.statusCode}).');
    }

    final newCookie = response.headers['set-cookie'];
    if (newCookie != null) {
      final extracted = _extractCookie(newCookie);
      if (extracted != null) _cookie = extracted;
    }

    if (response.body.contains('top.location.replace(\'/\')') || !response.body.contains('login')) return;
    throw Exception('Huawei login was not accepted.');
  }

  String _base64(String value) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final bytes = value.codeUnits;
    final out = StringBuffer();
    var i = 0;
    while (i < bytes.length) {
      final a = bytes[i++];
      final b = i < bytes.length ? bytes[i++] : null;
      final c = i < bytes.length ? bytes[i++] : null;
      final triple = (a << 16) | ((b ?? 0) << 8) | (c ?? 0);
      out.write(chars[(triple >> 18) & 63]);
      out.write(chars[(triple >> 12) & 63]);
      out.write(b == null ? '=' : chars[(triple >> 6) & 63]);
      out.write(c == null ? '=' : chars[triple & 63]);
    }
    return out.toString();
  }

  Future<String> _getPage() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/html/bbsp/portacl/newacl.asp'),
      headers: {
        ..._headers(),
        'Referer': '$_baseUrl/index.asp',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Device Access Control page failed (HTTP ${response.statusCode}).');
    }
    return response.body;
  }

  String? _extractToken(String body) {
    final patterns = <RegExp>[
      RegExp(r'''name\s*=\s*["']x\.X_HW_Token["'][^>]*value\s*=\s*["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''value\s*=\s*["']([^"']+)["'][^>]*name\s*=\s*["']x\.X_HW_Token["']''', caseSensitive: false),
      RegExp(r'''x\.X_HW_Token\s*[=:]\s*["']([^"']+)["']''', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final value = match.group(1)?.trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  bool _extractEnabled(String body) {
    final patterns = <RegExp>[
      RegExp(r'''<input[^>]*name\s*=\s*["']x\.AccessControlListEnable["'][^>]*checked(?:\s*=\s*["']?(?:checked|true|1)["']?)?[^>]*>''', caseSensitive: false),
      RegExp(r'''<input[^>]*checked(?:\s*=\s*["']?(?:checked|true|1)["']?)?[^>]*name\s*=\s*["']x\.AccessControlListEnable["'][^>]*>''', caseSensitive: false),
      RegExp(r'''x\.AccessControlListEnable\s*[=:]\s*["']?1["']?''', caseSensitive: false),
    ];
    return patterns.any((pattern) => pattern.hasMatch(body));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      await _login();
      final page = await _getPage();
      final token = _extractToken(page);
      if (token == null) {
        throw Exception('Huawei did not expose the Device Access Control token.');
      }
      if (!mounted) return;
      setState(() {
        _token = token;
        _enabled = _extractEnabled(page);
        _stateKnown = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      final page = await _getPage();
      final token = _extractToken(page);
      if (token == null) throw Exception('Huawei did not expose a fresh Device Access Control token.');

      final query = <String, String>{
        'x': 'InternetGatewayDevice.X_HW_Security.AclServices.AccessControl',
        'RequestFile': 'html/bbsp/portacl/newacl.asp',
      };
      final uri = Uri.parse('$_baseUrl/html/bbsp/portacl/set.cgi').replace(queryParameters: query);

      final body = <String, String>{
        if (value) 'x.AccessControlListEnable': '1',
        'x.X_HW_Token': token,
      };

      final response = await http.post(
        uri,
        headers: {
          ..._headers(),
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
          'Cache-Control': 'max-age=0',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': _baseUrl,
          'Referer': '$_baseUrl/html/bbsp/portacl/newacl.asp',
        },
        body: body,
      );

      if (response.statusCode != 200 && response.statusCode != 404) {
        throw Exception('Huawei did not accept the Device Access Control request (HTTP ${response.statusCode}).');
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
      final verifyPage = await _getPage();
      final actual = _extractEnabled(verifyPage);
      if (actual != value) {
        throw Exception('Huawei did not confirm Device Access Control was ${value ? 'enabled' : 'disabled'}.');
      }

      if (!mounted) return;
      setState(() {
        _enabled = actual;
        _stateKnown = true;
        _success = 'Precise device access control ${actual ? 'enabled' : 'disabled'} successfully.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addDefaultRule() async {
    if (_addingRule) return;
    setState(() {
      _addingRule = true;
      _error = null;
      _success = null;
    });

    try {
      final page = await _getPage();
      final token = _extractToken(page);
      if (token == null) throw Exception('Huawei did not expose a fresh Device Access Control token.');

      final query = <String, String>{
        'x': 'InternetGatewayDevice.X_HW_Security.AclServices.AccessControl.List',
        'RequestFile': 'html/bbsp/portacl/newacl.asp',
      };
      final uri = Uri.parse('$_baseUrl/html/bbsp/portacl/add.cgi').replace(queryParameters: query);

      final body = <String, String>{
        'x.Priority': '1',
        'x.SrcPortName': 'ALL',
        'x.ServicePort': 'HTTP,FTP,ICMP,SAMBA',
        'x.SrcPortType': '2',
        'x.SrcIp': '',
        'x.Mode': '0',
        'x.ServiceProto': '',
        'x.ServiceProtoPort': '',
        'x.X_HW_Token': token,
      };

      final response = await http.post(
        uri,
        headers: {
          ..._headers(),
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
          'Cache-Control': 'max-age=0',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': _baseUrl,
          'Referer': '$_baseUrl/html/bbsp/portacl/newacl.asp',
        },
        body: body,
      );

      if (response.statusCode != 200 && response.statusCode != 404) {
        throw Exception('Huawei did not accept the new access-control rule (HTTP ${response.statusCode}).');
      }

      if (!mounted) return;
      setState(() => _success = 'Default access-control rule was submitted successfully.');
    } catch (e) {
      if (mounted) setState(() => _error = _cleanError(e));
    } finally {
      if (mounted) setState(() => _addingRule = false);
    }
  }

  String _cleanError(Object error) => error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('Device Access Control', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _saving || _addingRule ? null : _load,
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
                          Icon(Icons.security_rounded, color: Colors.white, size: 34),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Device Access Control', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text('Huawei precise access control', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (_error != null) const SizedBox(height: 12),
                    if (_success != null)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_success!, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (_success != null) const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Precise Device Access Control', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text('Matches the Huawei checkbox and its actual enable/disable requests.', style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 18),
                            if (!_stateKnown)
                              const Text('Huawei did not expose the current state.')
                            else
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: Text(_enabled ? 'Enabled' : 'Disabled', style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(_enabled ? 'Precise device access control is active.' : 'Precise device access control is inactive.'),
                                value: _enabled,
                                onChanged: _saving ? null : _setEnabled,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quick Rule', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text('One click submits the exact rule from your Huawei capture.', style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 14),
                            const Text('Priority 1 • Source ALL • HTTP, FTP, ICMP, SAMBA', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _addingRule || _saving ? null : _addDefaultRule,
                                icon: _addingRule ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_task_rounded),
                                label: Text(_addingRule ? 'Adding...' : 'Add Default Rule'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
