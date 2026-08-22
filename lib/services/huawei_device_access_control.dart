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

  bool _isAccessControlEnabled(String body) {
    final match = RegExp(
      r'''<input[^>]*id\s*=\s*["']portaclwhite["'][^>]*>''',
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) return false;
    return RegExp(r'\bchecked\b', caseSensitive: false)
        .hasMatch(match.group(0)!);
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

  Future<HuaweiDeviceAccessControlStatus> getStatus() async {
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

    final token = _extractOntToken(response.body);
    if (token == null) {
      throw Exception(
        'Device Access Control page did not provide onttoken.',
      );
    }

    return HuaweiDeviceAccessControlStatus(
      enabled: _isAccessControlEnabled(response.body),
      httpStatus: response.statusCode,
      sidLength: _sid!.length,
      tokenLength: token.length,
    );
  }

  Future<HuaweiDeviceAccessControlStatus> setEnabled(bool enabled) async {
    if (_cookie == null || _sid == null) {
      throw Exception(
        'Huawei session is not available. Please log in again.',
      );
    }

    // Confirmed EG8145V5 behavior from the browser:
    // ON  -> x.AccessControlListEnable=1 + x.X_HW_Token
    // OFF -> x.X_HW_Token only
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

    // HTTP 200 alone is NOT treated as success. Huawei's browser performs
    // follow-up requests and the page state is authoritative.
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

  void close() => _client.close();
}
