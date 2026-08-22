import 'dart:convert';

import 'package:http/http.dart' as http;

class HuaweiDeviceAccessControlStatus {
  final bool enabled;
  final int httpStatus;
  final int sidLength;
  final int tokenLength;

  const HuaweiDeviceAccessControlStatus({
    required this.enabled,
    required this.httpStatus,
    required this.sidLength,
    required this.tokenLength,
  });
}

class HuaweiAccessControlRule {
  final String priority;
  final String srcPortName;
  final String servicePort;
  final String srcPortType;
  final String srcIp;
  final String mode;
  final String serviceProto;
  final String serviceProtoPort;

  const HuaweiAccessControlRule({
    required this.priority,
    required this.srcPortName,
    required this.servicePort,
    required this.srcPortType,
    required this.srcIp,
    required this.mode,
    required this.serviceProto,
    required this.serviceProtoPort,
  });
}

class HuaweiDeviceAccessControlService {
  final String baseUrl;
  final http.Client _client;

  String? _cookie;
  String? _loginToken;
  String? _sid;

  HuaweiDeviceAccessControlService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> _headers({String? referer, bool form = false}) {
    final headers = <String, String>{
      'Accept': '*/*',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
    };
    if (_cookie != null) headers['Cookie'] = _cookie!;
    if (referer != null) headers['Referer'] = referer;
    if (form) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      headers['Origin'] = baseUrl;
    }
    return headers;
  }

  String? _extractCookie(String? setCookie) {
    if (setCookie == null || setCookie.trim().isEmpty) return null;
    final first = setCookie.split(';').first.trim();
    return first.isEmpty ? null : first;
  }

  String? _extractSid(String? cookie) {
    if (cookie == null) return null;
    final match = RegExp(
      r'(?:^|\s|Cookie=)sid=([^:;\s]+)',
      caseSensitive: false,
    ).firstMatch(cookie);
    return match?.group(1);
  }

  String? _extractOntToken(String body) {
    final patterns = <RegExp>[
      RegExp(
        r'''<input[^>]*id\s*=\s*["']onttoken["'][^>]*value\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<input[^>]*name\s*=\s*["']onttoken["'][^>]*value\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<input[^>]*value\s*=\s*["']([^"']+)["'][^>]*name\s*=\s*["']onttoken["']''',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool? _extractHuaweiAccessControlState(String body) {
    final match = RegExp(
      r'''var\s+NewAclEnableInfo\s*=\s*new\s+Array\s*\(\s*new\s+stNewAclEnable\s*\(\s*["']InternetGatewayDevice\.X_HW_Security\.AclServices\.AccessControl["']\s*,\s*["']([01])["']\s*\)''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body);

    final value = match?.group(1);
    if (value == '1') return true;
    if (value == '0') return false;

    return _isAccessControlEnabledFromInput(body);
  }

  bool? _isAccessControlEnabledFromInput(String body) {
    final inputTags = RegExp(
      r'<input\b[^>]*>',
      caseSensitive: false,
    ).allMatches(body);

    for (final match in inputTags) {
      final tag = match.group(0)!;
      final id = RegExp(
        r'''\bid\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(tag)?.group(1);
      final name = RegExp(
        r'''\bname\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(tag)?.group(1);

      final isAccessControlInput =
          id?.toLowerCase() == 'portaclwhite' ||
          name?.toLowerCase() == 'portaclwhite' ||
          id?.toLowerCase() == 'accesscontrollistenable' ||
          name?.toLowerCase() == 'accesscontrollistenable';

      if (!isAccessControlInput) continue;

      return RegExp(
        r'''\bchecked(?:\s*=\s*["']?checked["']?)?\b''',
        caseSensitive: false,
      ).hasMatch(tag);
    }

    return null;
  }

  HuaweiDeviceAccessControlStatus _statusFromPage({
    required String body,
    required int httpStatus,
    required String token,
  }) {
    final enabled = _extractHuaweiAccessControlState(body);
    if (enabled == null) {
      throw Exception(
        'Huawei Access Control state could not be parsed from newacl.asp. '
        'NewAclEnableInfo and the checkbox fallback were both unavailable. '
        'This is a parser/firmware response mismatch, not an OFF state.',
      );
    }

    return HuaweiDeviceAccessControlStatus(
      enabled: enabled,
      httpStatus: httpStatus,
      sidLength: _sid!.length,
      tokenLength: token.length,
    );
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final randResponse = await _client.get(
      Uri.parse('$baseUrl/asp/GetRandCount.asp'),
      headers: _headers(),
    );
    if (randResponse.statusCode != 200) {
      throw Exception(
        'Unable to connect to Huawei router (HTTP ${randResponse.statusCode}).',
      );
    }

    _loginToken = randResponse.body.replaceFirst('\uFEFF', '').trim();
    if (_loginToken == null || _loginToken!.isEmpty) {
      throw Exception('Huawei router did not return a login token.');
    }
    _cookie = _extractCookie(randResponse.headers['set-cookie']);

    final encodedPassword = base64Encode(utf8.encode(password));
    final response = await _client.post(
      Uri.parse('$baseUrl/login.cgi'),
      headers: _headers(
        referer: '$baseUrl/login.asp',
        form: true,
      ),
      body: {
        'UserName': username,
        'PassWord': encodedPassword,
        'Language': 'english',
        'x.X_HW_Token': _loginToken!,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Huawei login failed (HTTP ${response.statusCode}).');
    }

    final newCookie = _extractCookie(response.headers['set-cookie']);
    if (newCookie != null) _cookie = newCookie;
    _sid = _extractSid(_cookie);

    final accepted = response.body.contains("top.location.replace('/')") ||
        !response.body.toLowerCase().contains('login');
    if (!accepted || _sid == null || _sid!.isEmpty) {
      throw Exception(
        'Huawei login was not accepted or no SID was established.',
      );
    }
  }

  Future<String> _getAccessControlPage() async {
    if (_cookie == null || _sid == null) {
      throw Exception(
        'Huawei session is not available. Please log in again.',
      );
    }

    final response = await _client.get(
      Uri.parse('$baseUrl/html/bbsp/portacl/newacl.asp'),
      headers: _headers(referer: '$baseUrl/index.asp'),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Device Access Control page returned HTTP ${response.statusCode}.',
      );
    }

    return response.body;
  }

  Future<HuaweiDeviceAccessControlStatus> getStatus() async {
    final body = await _getAccessControlPage();

    final token = _extractOntToken(body);
    if (token == null) {
      throw Exception(
        'Device Access Control page did not provide onttoken.',
      );
    }

    return _statusFromPage(
      body: body,
      httpStatus: 200,
      token: token,
    );
  }

  /// Returns the Access Control List indexes that Huawei exposes in the
  /// current newacl.asp response.
  ///
  /// This deliberately looks for the actual AccessControl.List.N object path
  /// rather than guessing a fixed maximum index.
  Future<List<int>> getEntryIndices() async {
    final body = await _getAccessControlPage();
    final matches = RegExp(
      r'InternetGatewayDevice\.X_HW_Security\.AclServices\.AccessControl\.List\.(\d+)',
    ).allMatches(body);

    final indices = <int>{};
    for (final match in matches) {
      final value = int.tryParse(match.group(1)!);
      if (value != null && value > 0) indices.add(value);
    }

    final result = indices.toList()..sort();
    return result;
  }

  Future<HuaweiDeviceAccessControlStatus> setEnabled(bool enabled) async {
    if (_cookie == null || _sid == null) {
      throw Exception(
        'Huawei session is not available. Please log in again.',
      );
    }

    final pageResponse = await _client.get(
      Uri.parse('$baseUrl/html/bbsp/portacl/newacl.asp'),
      headers: _headers(referer: '$baseUrl/index.asp'),
    );
    if (pageResponse.statusCode != 200) {
      throw Exception(
        'Unable to refresh Device Access Control page '
        '(HTTP ${pageResponse.statusCode}).',
      );
    }

    final token = _extractOntToken(pageResponse.body);
    if (token == null) {
      throw Exception(
        'Device Access Control page did not provide a fresh onttoken.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/html/bbsp/portacl/set.cgi'
      '?x=InternetGatewayDevice.X_HW_Security.AclServices.AccessControl'
      '&RequestFile=html/bbsp/portacl/newacl.asp',
    );

    final body = <String, String>{
      if (enabled) 'x.AccessControlListEnable': '1',
      'x.X_HW_Token': token,
    };

    final response = await _client.post(
      uri,
      headers: _headers(
        referer: '$baseUrl/html/bbsp/portacl/newacl.asp',
        form: true,
      ),
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Huawei rejected the Device Access Control request '
        '(HTTP ${response.statusCode}).',
      );
    }

    final actual = await getStatus();

    if (actual.enabled != enabled) {
      throw Exception(
        'Router verification failed: requested '
        '${enabled ? 'ON' : 'OFF'}, but Huawei reports '
        '${actual.enabled ? 'ON' : 'OFF'}. '
        'The router did not apply the requested state.',
      );
    }

    return actual;
  }

  Future<void> prepareAddEntry() async {
    if (_cookie == null || _sid == null) {
      throw Exception('Huawei session is not available. Please log in again.');
    }

    final response = await _client.get(
      Uri.parse('$baseUrl/html/ssmp/common/StartFileLoad.asp'),
      headers: _headers(
        referer: '$baseUrl/html/bbsp/portacl/newacl.asp',
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Huawei StartFileLoad request failed '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  Future<void> addEntry(HuaweiAccessControlRule rule) async {
    if (_cookie == null || _sid == null) {
      throw Exception('Huawei session is not available. Please log in again.');
    }

    final pageResponse = await _client.get(
      Uri.parse('$baseUrl/html/bbsp/portacl/newacl.asp'),
      headers: _headers(
        referer: '$baseUrl/html/bbsp/portacl/newacl.asp',
      ),
    );

    if (pageResponse.statusCode != 200) {
      throw Exception(
        'Unable to refresh the Access Control form '
        '(HTTP ${pageResponse.statusCode}).',
      );
    }

    final token = _extractOntToken(pageResponse.body);
    if (token == null) {
      throw Exception(
        'Access Control form did not provide a fresh onttoken.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/html/bbsp/portacl/add.cgi'
      '?x=InternetGatewayDevice.X_HW_Security.AclServices.AccessControl.List'
      '&RequestFile=html/bbsp/portacl/newacl.asp',
    );

    final response = await _client.post(
      uri,
      headers: _headers(
        referer: '$baseUrl/html/bbsp/portacl/newacl.asp',
        form: true,
      ),
      body: {
        'x.Priority': rule.priority,
        'x.SrcPortName': rule.srcPortName,
        'x.ServicePort': rule.servicePort,
        'x.SrcPortType': rule.srcPortType,
        'x.SrcIp': rule.srcIp,
        'x.Mode': rule.mode,
        'x.ServiceProto': rule.serviceProto,
        'x.ServiceProtoPort': rule.serviceProtoPort,
        'x.X_HW_Token': token,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Huawei rejected the Access Control entry '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  Future<void> prepareDeleteEntry() async {
    if (_cookie == null || _sid == null) {
      throw Exception('Huawei session is not available. Please log in again.');
    }

    final response = await _client.get(
      Uri.parse('$baseUrl/html/ssmp/common/StartFileLoad.asp'),
      headers: _headers(
        referer: '$baseUrl/html/bbsp/portacl/add.cgi'
            '?x=InternetGatewayDevice.X_HW_Security.AclServices.AccessControl.List'
            '&RequestFile=html/bbsp/portacl/newacl.asp',
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Huawei StartFileLoad request before delete failed '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  /// Deletes one confirmed Huawei Access Control List entry.
  ///
  /// The browser capture supplied during development showed:
  ///
  /// POST /html/bbsp/portacl/del.cgi
  /// ?x=InternetGatewayDevice.X_HW_Security.AclServices.AccessControl.List
  /// &RequestFile=html/bbsp/portacl/newacl.asp
  ///
  /// Form fields:
  /// InternetGatewayDevice.X_HW_Security.AclServices.AccessControl.List.N=
  /// x.X_HW_Token=`<fresh token>`
  Future<void> deleteEntry(int index) async {
    if (_cookie == null || _sid == null) {
      throw Exception('Huawei session is not available. Please log in again.');
    }
    if (index <= 0) {
      throw Exception('Invalid Access Control entry index: $index.');
    }

    final pageResponse = await _client.get(
      Uri.parse('$baseUrl/html/bbsp/portacl/newacl.asp'),
      headers: _headers(
        referer: '$baseUrl/html/bbsp/portacl/newacl.asp',
      ),
    );

    if (pageResponse.statusCode != 200) {
      throw Exception(
        'Unable to refresh the Access Control page before delete '
        '(HTTP ${pageResponse.statusCode}).',
      );
    }

    final token = _extractOntToken(pageResponse.body);
    if (token == null) {
      throw Exception(
        'Access Control page did not provide a fresh onttoken for delete.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/html/bbsp/portacl/del.cgi'
      '?x=InternetGatewayDevice.X_HW_Security.AclServices.AccessControl.List'
      '&RequestFile=html/bbsp/portacl/newacl.asp',
    );

    final response = await _client.post(
      uri,
      headers: _headers(
        referer: '$baseUrl/html/bbsp/portacl/add.cgi'
            '?x=InternetGatewayDevice.X_HW_Security.AclServices.AccessControl.List'
            '&RequestFile=html/bbsp/portacl/newacl.asp',
        form: true,
      ),
      body: {
        'InternetGatewayDevice.X_HW_Security.AclServices.AccessControl.List.$index': '',
        'x.X_HW_Token': token,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Huawei rejected Access Control entry deletion '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  /// Deletes all entry indexes discovered from the current Huawei page.
  ///
  /// The list is re-read before and after the operation. We never guess a
  /// fixed range of indexes, which avoids accidentally targeting unrelated
  /// objects on a different firmware.
  Future<int> deleteAllEntries() async {
    var indices = await getEntryIndices();
    if (indices.isEmpty) return 0;

    var deleted = 0;
    for (final index in indices) {
      await prepareDeleteEntry();
      await deleteEntry(index);
      deleted++;
    }

    final remaining = await getEntryIndices();
    if (remaining.isNotEmpty) {
      throw Exception(
        'Huawei still reports ${remaining.length} Access Control '
        'entry/entries after deletion: ${remaining.join(', ')}.',
      );
    }

    return deleted;
  }

  Future<void> logout() async {
    if (_cookie == null || _cookie!.isEmpty || _sid == null || _sid!.isEmpty) {
      throw Exception('Huawei Access Control session is not available.');
    }

    final page = await _getAccessControlPage();
    final token = _extractOntToken(page);
    if (token == null || token.isEmpty) {
      throw Exception('Huawei Access Control page did not provide a fresh token for logout.');
    }

    final uri = Uri.parse('$baseUrl/logout.cgi').replace(
      queryParameters: {'RequestFile': 'html/logout.html'},
    );

    final response = await _client.post(
      uri,
      headers: {
        ..._headers(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
        'Cache-Control': 'max-age=0',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/index.asp',
        'Upgrade-Insecure-Requests': '1',
      },
      body: {'x.X_HW_Token': token},
    );

    if (response.statusCode != 200) {
      throw Exception('Huawei Access Control logout failed (HTTP ${response.statusCode}).');
    }

    _cookie = null;
    _loginToken = null;
    _sid = null;
  }

  void close() => _client.close();
}