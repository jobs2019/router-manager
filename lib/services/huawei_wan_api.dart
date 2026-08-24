import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/huawei_wan_configuration.dart';

class HuaweiWanApi {
  HuaweiWanApi({required this.baseUrl});

  final String baseUrl;
  String? _token;
  String? _cookie;

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Accept': '*/*',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
    };
    if (_cookie != null) headers['Cookie'] = _cookie!;
    return headers;
  }

  String? _extractCookie(String value) {
    final first = value.split(';').first.trim();
    return first.isEmpty ? null : first;
  }

  Future<void> _getSession() async {
    final response = await http.get(
      Uri.parse('$baseUrl/asp/GetRandCount.asp'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to connect to Huawei router (HTTP ${response.statusCode}).');
    }
    _token = response.body.trim();
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) _cookie = _extractCookie(setCookie);
    if (_token == null || _token!.isEmpty) {
      throw Exception('Huawei router did not return a login token.');
    }
  }

  Future<void> login({required String username, required String password}) async {
    await _getSession();
    final response = await http.post(
      Uri.parse('$baseUrl/login.cgi'),
      headers: {
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': '$baseUrl/login.asp',
        'Origin': baseUrl,
      },
      body: {
        'UserName': username,
        'PassWord': base64Encode(utf8.encode(password)),
        'Language': 'english',
        'x.X_HW_Token': _token!,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Huawei login failed (HTTP ${response.statusCode}).');
    }
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final cookie = _extractCookie(setCookie);
      if (cookie != null) _cookie = cookie;
    }
    if (response.body.contains("top.location.replace('/')") ||
        !response.body.contains('login')) {
      return;
    }
    throw Exception('Huawei login was not accepted. Please check the username and password.');
  }

  Future<String> _getWanPageToken() async {
    final response = await http.get(
      Uri.parse('$baseUrl/html/bbsp/wan/wan.asp'),
      headers: {
        ..._headers(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': '$baseUrl/index.asp',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to open Huawei WAN configuration (HTTP ${response.statusCode}).');
    }
    return _extractOntToken(response.body);
  }

  String _extractOntToken(String body) {
    final patterns = <RegExp>[
      RegExp(r'''<input[^>]*name=["']onttoken["'][^>]*value=["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''<input[^>]*value=["']([^"']+)["'][^>]*name=["']onttoken["']''', caseSensitive: false),
      RegExp(r'''var\s+onttoken\s*=\s*["']([^"']+)["']''', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      final token = match?.group(1)?.trim();
      if (token != null && token.isNotEmpty) return token;
    }
    throw Exception('Huawei WAN page did not provide onttoken.');
  }

  Future<List<HuaweiWanConfiguration>> getWanConfigurations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/html/bbsp/common/wan_list.asp?${DateTime.now().millisecondsSinceEpoch}'),
      headers: {
        ..._headers(),
        'Referer': '$baseUrl/html/bbsp/wan/wan.asp',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('WAN configuration request failed: HTTP ${response.statusCode}.');
    }

    final body = response.body;
    final bindings = <String, List<String>>{};
    final policyPattern = RegExp(r'new\s+PolicyRouteItem\((.*?)\)', dotAll: true);
    for (final match in policyPattern.allMatches(body)) {
      final values = _parseHuaweiQuotedValues(match.group(1) ?? '');
      if (values.length < 6) continue;
      final wanName = values[3];
      final ports = values[5].trim();
      if (wanName.isEmpty || ports.isEmpty) continue;
      bindings[wanName] = ports
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    final result = <HuaweiWanConfiguration>[];
    final wanPattern = RegExp(r'new\s+WanPPP\((.*?)\)', dotAll: true);
    for (final match in wanPattern.allMatches(body)) {
      final values = _parseHuaweiQuotedValues(match.group(1) ?? '');
      if (values.length < 39) continue;

      // Huawei's WanPPP constructor fields are:
      // 0 domain, 3 status, 6 display name, 17 username,
      // 18 password, 21 VLAN ID.
      final domain = values[0];
      final wanName = values[6].trim().isNotEmpty
          ? values[6].trim()
          : _domainToWanName(domain);

      result.add(
        HuaweiWanConfiguration(
          domain: domain,
          wanName: wanName,
          status: values[3],
          vlanId: values[21],
          username: values[17],
          password: values[18],
          bindings: List<String>.from(bindings[wanName] ?? const <String>[]),
        ),
      );
    }

    if (result.isEmpty) {
      throw Exception('No PPPoE WAN configuration was found.');
    }
    return result;
  }

  List<String> _parseHuaweiQuotedValues(String raw) {
    return [
      for (final match in RegExp(r'"((?:\\.|[^"])*)"').allMatches(raw))
        _decodeHuaweiValue(match.group(1)!),
    ];
  }

  String _decodeHuaweiValue(String value) {
    return value.replaceAllMapped(
      RegExp(r'\\x([0-9A-Fa-f]{2})'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
  }

  String _domainToWanName(String domain) {
    final parts = domain.split('.');
    if (parts.length >= 7) {
      final type = domain.contains('WANPPPConnection') ? 'ppp' : 'ip';
      return 'wan${parts[2]}.${parts[4]}.$type${parts[6]}';
    }
    return domain;
  }

  Map<String, String> _wanParameters({
    required String prefix,
    required int vlanId,
    required String username,
    required String password,
    required List<String> bindings,
  }) {
    return {
      '${prefix}Enable': '1',
      '${prefix}X_HW_IPv4Enable': '1',
      '${prefix}X_HW_IPv6Enable': '0',
      '${prefix}X_HW_IPv6MultiCastVLAN': '-1',
      '${prefix}X_HW_SERVICELIST': 'INTERNET',
      '${prefix}X_HW_ExServiceList': '',
      '${prefix}X_HW_VLAN': vlanId.toString(),
      '${prefix}X_HW_PRI': '0',
      '${prefix}X_HW_PriPolicy': 'Specified',
      '${prefix}X_HW_DefaultPri': '0',
      '${prefix}ConnectionType': 'IP_Routed',
      '${prefix}X_HW_MultiCastVLAN': '4294967295',
      '${prefix}NATEnabled': '1',
      '${prefix}X_HW_NatType': '0',
      '${prefix}Username': username,
      '${prefix}Password': password,
      '${prefix}X_HW_LcpEchoReqCheck': '0',
      '${prefix}ConnectionTrigger': 'AlwaysOn',
      '${prefix}DNSEnabled': '1',
      '${prefix}MaxMRUSize': '1492',
      '${prefix}DNSOverrideAllowed': '0',
      '${prefix}DNSServers': '',
      '${prefix}X_HW_BindPhyPortInfo': bindings.join(','),
    };
  }

  Future<void> addPppoeWan({
    required int vlanId,
    required String username,
    required String password,
    required List<String> bindings,
  }) async {
    _requireSession();
    _validate(vlanId, username, password, requirePassword: true);
    final token = await _getWanPageToken();
    final uri = Uri.parse('$baseUrl/html/bbsp/wan/addcfg.cgi').replace(
      queryParameters: {
        'GROUP_a_x': 'InternetGatewayDevice.WANDevice.1.WANConnectionDevice',
        'GROUP_a_y': 'GROUP_a_x.WANPPPConnection',
        'RequestFile': 'html/bbsp/wan/confirmwancfginfo.html',
      },
    );
    final body = _wanParameters(
      prefix: 'GROUP_a_y.',
      vlanId: vlanId,
      username: username.trim(),
      password: password,
      bindings: bindings,
    )..['x.X_HW_Token'] = token;

    final response = await http.post(
      uri,
      headers: {
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/html/bbsp/wan/wan.asp',
      },
      body: body,
    );
    _checkMutation(response, 'add');
  }

  Future<void> editPppoeWan({
    required String domain,
    required int vlanId,
    required String username,
    required String password,
    required List<String> bindings,
  }) async {
    _requireSession();
    if (!domain.contains('WANPPPConnection')) {
      throw Exception('The selected WAN is not a PPPoE WAN.');
    }
    _validate(vlanId, username, password, requirePassword: true);
    final token = await _getWanPageToken();
    final uri = Uri.parse('$baseUrl/html/bbsp/wan/complex.cgi').replace(
      queryParameters: {
        'y': domain,
        'RequestFile': 'html/bbsp/wan/confirmwancfginfo.html',
      },
    );
    final body = _wanParameters(
      prefix: 'y.',
      vlanId: vlanId,
      username: username.trim(),
      password: password,
      bindings: bindings,
    )
      ..['X_HW_OverrideAllowed'] = '0'
      ..['x.X_HW_Token'] = token;

    final response = await http.post(
      uri,
      headers: {
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/html/bbsp/wan/wan.asp',
      },
      body: body,
    );
    _checkMutation(response, 'edit');
  }

  void _requireSession() {
    if (_cookie == null || _token == null) {
      throw Exception('Huawei session is not available. Please log in again.');
    }
  }

  void _validate(int vlanId, String username, String password, {required bool requirePassword}) {
    if (vlanId < 1 || vlanId > 4094) {
      throw Exception('VLAN ID must be between 1 and 4094.');
    }
    if (username.trim().isEmpty) {
      throw Exception('PPPoE username is required.');
    }
    if (requirePassword && password.isEmpty) {
      throw Exception('PPPoE password is required.');
    }
  }

  void _checkMutation(http.Response response, String operation) {
    if (response.statusCode != 200) {
      throw Exception('Unable to $operation Huawei WAN configuration (HTTP ${response.statusCode}).');
    }
    final body = response.body.toLowerCase();
    if (body.contains('login.asp') && body.contains('username')) {
      throw Exception('Huawei session expired. Please log in again.');
    }
  }
}
