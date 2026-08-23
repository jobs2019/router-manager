import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/huawei_simple_wifi_settings.dart';
import '../models/huawei_wifi_settings.dart';

class HuaweiApi {
  final String baseUrl;
  String? _token;
  String? _cookie;

  HuaweiApi({required this.baseUrl});

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

  Future<void> _getSession() async {
    final response = await http.get(
      Uri.parse('$baseUrl/asp/GetRandCount.asp'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Unable to connect to Huawei router (HTTP ${response.statusCode}).',
      );
    }
    _token = response.body.trim();
    if (_token == null || _token!.isEmpty) {
      throw Exception('Huawei router did not return a login token.');
    }
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) _cookie = _extractCookie(setCookie);
  }

  String? _extractCookie(String value) {
    final first = value.split(';').first.trim();
    return first.isEmpty ? null : first;
  }

  Future<bool> login({required String username, required String password}) async {
    await _getSession();
    final encodedPassword = base64Encode(utf8.encode(password));
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
        'PassWord': encodedPassword,
        'Language': 'english',
        'x.X_HW_Token': _token!,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Huawei login failed (HTTP ${response.statusCode}).');
    }
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final newCookie = _extractCookie(setCookie);
      if (newCookie != null) _cookie = newCookie;
    }
    if (response.body.contains("top.location.replace('/')") ||
        !response.body.contains('login')) {
      return true;
    }
    throw Exception(
      'Huawei login was not accepted. Please check the username and password.',
    );
  }

  Future<void> logout() async {
    if (_cookie == null || _cookie!.isEmpty) {
      throw Exception('Huawei session is not available.');
    }
    final pageResponse = await http.get(
      Uri.parse('$baseUrl/html/bbsp/portacl/newacl.asp'),
      headers: {..._headers(), 'Referer': '$baseUrl/index.asp'},
    );
    if (pageResponse.statusCode != 200) {
      throw Exception(
        'Unable to obtain the current Huawei session token before logout '
        '(HTTP ${pageResponse.statusCode}).',
      );
    }
    final token = _getOntToken(pageResponse.body);
    final uri = Uri.parse('$baseUrl/logout.cgi').replace(
      queryParameters: {'RequestFile': 'html/logout.html'},
    );
    final response = await http.post(
      uri,
      headers: {
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/index.asp',
      },
      body: {'x.X_HW_Token': token},
    );
    if (response.statusCode != 200) {
      throw Exception('Huawei logout failed (HTTP ${response.statusCode}).');
    }
    _token = null;
    _cookie = null;
  }

  Future<String> getPage(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Huawei router returned HTTP ${response.statusCode}.');
    }
    return response.body;
  }

  Future<List<Map<String, String>>> getWanStatus() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/html/bbsp/common/getwanlist.asp?'
        '${DateTime.now().millisecondsSinceEpoch}',
      ),
      headers: {
        ..._headers(),
        'Referer': '$baseUrl/html/bbsp/waninfo/waninfo.asp',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('WAN request failed: HTTP ${response.statusCode}');
    }
    final wanMatches = RegExp(
      r'new\s+WanPPP\((.*?)\)',
      dotAll: true,
    ).allMatches(response.body);
    if (wanMatches.isEmpty) {
      throw Exception('No WAN connection was found.');
    }
    final wanList = <Map<String, String>>[];
    for (final wanMatch in wanMatches) {
      final raw = wanMatch.group(1);
      if (raw == null || raw.isEmpty) continue;
      final values = <String>[];
      for (final match in RegExp(r'"((?:\\.|[^"])*)"').allMatches(raw)) {
        values.add(_decodeHuaweiValue(match.group(1)!));
      }
      if (values.length < 25) continue;
      var vlanId = values[22];
      if (vlanId.isEmpty || vlanId == '0') vlanId = '-';
      var ipAddress = values[13];
      if (ipAddress.isEmpty) ipAddress = '0.0.0.0';
      wanList.add({
        'domain': values[0],
        'wanName': values[7],
        'status': values[4],
        'ipAddress': ipAddress,
        'vlanId': vlanId,
      });
    }
    if (wanList.isEmpty) {
      throw Exception('No usable WAN connection was found.');
    }
    return wanList;
  }

  Future<String> _get2GBasicPage() async {
    final response = await http.get(
      Uri.parse('$baseUrl/html/amp/wlanbasic/WlanBasic.asp?2G'),
      headers: {
        ..._headers(),
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': '$baseUrl/index.asp',
      },
    );
    if (response.statusCode != 200) {
      throw Exception(
        '2.4 GHz Wi-Fi settings request failed: HTTP ${response.statusCode}',
      );
    }
    return response.body;
  }

  String _inputValue(String body, String name, {String fallback = ''}) {
    final escaped = RegExp.escape(name);
    final patterns = <RegExp>[
      RegExp(
        '<input[^>]+name=["\\\']$escaped["\\\'][^>]+value=["\\\']([^"\\\']*)["\\\']',
        caseSensitive: false,
      ),
      RegExp(
        '<input[^>]+value=["\\\']([^"\\\']*)["\\\'][^>]+name=["\\\']$escaped["\\\']',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        return _decodeHtml(match.group(1) ?? fallback);
      }
    }
    return fallback;
  }

  bool _inputChecked(String body, String name, {bool fallback = false}) {
    final escaped = RegExp.escape(name);
    final patterns = <RegExp>[
      RegExp(
        '<input[^>]+name=["\\\']$escaped["\\\'][^>]*checked[^>]*>',
        caseSensitive: false,
      ),
      RegExp(
        '<input[^>]+checked[^>]*name=["\\\']$escaped["\\\'][^>]*>',
        caseSensitive: false,
      ),
    ];
    return patterns.any((pattern) => pattern.hasMatch(body)) || fallback;
  }

  String _getOntToken(String body) {
    final patterns = <RegExp>[
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
      if (match != null) {
        final token = match.group(1)?.trim() ?? '';
        if (token.isNotEmpty) return _decodeHtml(token);
      }
    }
    throw Exception('Huawei 2.4 GHz page did not provide onttoken.');
  }

  String _get2GSsidFromPage(String body) {
    // Taken directly from the supplied EG8145V5 WlanBasic.asp structure:
    // WlanWifiArr contains stWlanWifi(domain, name, enable, ssid, ...).
    // The first entry is ath0 / WLANConfiguration.1 (2.4 GHz).
    final match = RegExp(
      r'''new\s+stWlanWifi\(\s*"((?:\\.|[^"])*)"\s*,\s*"ath0"\s*,\s*"((?:\\.|[^"])*)"\s*,\s*"((?:\\.|[^"])*)"''',
      dotAll: true,
    ).firstMatch(body);

    if (match != null) {
      final domain = _decodeHuaweiValue(match.group(1)!);
      final ssid = _decodeHuaweiValue(match.group(3)!).trim();
      if (domain.endsWith('WLANConfiguration.1') && ssid.isNotEmpty) {
        return ssid;
      }
    }

    throw Exception(
      'Huawei 2.4 GHz page did not contain the expected '
      'stWlanWifi/ath0 WLANConfiguration.1 entry.',
    );
  }

  Future<HuaweiWifiSettings> get2GWifiSettings() async {
    final body = await _get2GBasicPage();
    return HuaweiWifiSettings(
      enabled: _inputChecked(body, 'y.Enable', fallback: true),
      ssid: _get2GSsidFromPage(body),
      broadcastSsid: _inputChecked(
        body,
        'y.SSIDAdvertisementEnabled',
        fallback: true,
      ),
      wmmEnabled: _inputChecked(body, 'w.WMMEnable', fallback: true),
      maxAssociateNum:
          int.tryParse(_inputValue(body, 'w.MaxAssociateNum')) ?? 32,
      authenticationMode: 'PSKAuthentication',
      encryptionMode: 'TKIPandAESEncryption',
      groupRekey: int.tryParse(_inputValue(body, 'y.X_HW_GroupRekey')) ?? 3600,
      wpsEnabled: _inputChecked(body, 'z.Enable'),
    );
  }

  Future<String?> get2GWifiPassword() async {
    // Password is intentionally not used by the 2.4 GHz test screen.
    return null;
  }

  Future<void> update2GWifiNameAndPassword({
    required String ssid,
    required String password,
  }) async {
    // The current app UI only changes the 2.4 GHz SSID. The password
    // argument is retained for API compatibility and is deliberately ignored.
    if (_cookie == null) {
      throw Exception(
        'Huawei session is not available. Please log in again.',
      );
    }

    final trimmedSsid = ssid.trim();
    if (trimmedSsid.isEmpty || trimmedSsid.length > 32) {
      throw Exception('Wi-Fi name must contain 1–32 characters.');
    }

    final page = await _get2GBasicPage();
    final token = _getOntToken(page);
    const wlanDomain =
        'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1';

    // Matches the supplied Huawei SubmitForm() path for HiLinkRoll=1:
    // set.cgi?w=...WifiCoverSetWlanBasic&x=InternetGatewayDevice.LANDevice.1&y=<domain>
    final uri = Uri.parse('$baseUrl/html/amp/wlanbasic/set.cgi').replace(
      queryParameters: {
        'w': 'InternetGatewayDevice.X_HW_DEBUG.AMP.WifiCoverSetWlanBasic',
        'x': 'InternetGatewayDevice.LANDevice.1',
        'y': wlanDomain,
        'RequestFile': 'html/amp/wlanbasic/WlanBasic.asp',
      },
    );

    // Only SSID fields are sent. Password, security, WMM, broadcast,
    // enable, and other Wi-Fi settings are intentionally untouched.
    final form = <String, String>{
      'y.SSID': trimmedSsid,
      'w.SsidInst': '1',
      'w.SSID': trimmedSsid,
      'x.X_HW_Token': token,
    };

    final response = await http.post(
      uri,
      headers: {
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': '$baseUrl/html/amp/wlanbasic/WlanBasic.asp?2G',
        'Origin': baseUrl,
      },
      body: form,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Huawei did not accept the 2.4 GHz Wi-Fi name request '
        '(HTTP ${response.statusCode}).',
      );
    }

    final responseBody = response.body.toLowerCase();
    if (responseBody.contains('login.asp') &&
        responseBody.contains('username')) {
      throw Exception('Huawei session expired. Please log in again.');
    }

    Exception? lastVerificationError;
    for (var attempt = 0; attempt < 6; attempt++) {
      await Future<void>.delayed(
        Duration(milliseconds: 900 + (attempt * 500)),
      );
      try {
        final verifyPage = await _get2GBasicPage();
        final actualSsid = _get2GSsidFromPage(verifyPage);
        if (actualSsid == trimmedSsid) return;
        lastVerificationError = Exception(
          'Huawei did not apply the requested 2.4 GHz Wi-Fi name. '
          'Current name is "$actualSsid".',
        );
      } catch (e) {
        lastVerificationError = Exception(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }

    throw lastVerificationError ?? Exception(
      'Huawei did not confirm the requested 2.4 GHz Wi-Fi name.',
    );
  }

  Future<void> update2GWifiSettings({
    required HuaweiWifiSettings settings,
    String? password,
  }) async {
    await update2GWifiNameAndPassword(
      ssid: settings.ssid,
      password: password ?? '',
    );
  }

  Future<HuaweiSimpleWifiSettings> getSimpleWifiSettings() async {
    throw Exception('5 GHz/simple Wi-Fi test is temporarily disabled.');
  }

  Future<void> updateSimpleWifiSettings({
    required HuaweiSimpleWifiBandSettings band2G,
    required HuaweiSimpleWifiBandSettings band5G,
    String? password2G,
    String? password5G,
  }) async {
    throw Exception('5 GHz/simple Wi-Fi test is temporarily disabled.');
  }

  Future<void> update5GWifiSettings({
    required HuaweiSimpleWifiBandSettings settings,
    String? password,
  }) async {
    throw Exception('5 GHz Wi-Fi test is temporarily disabled.');
  }

  String _decodeHtml(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  String _decodeHuaweiValue(String value) {
    return value.replaceAllMapped(
      RegExp(r'\\x([0-9A-Fa-f]{2})'),
      (match) => String.fromCharCode(
        int.parse(match.group(1)!, radix: 16),
      ),
    );
  }
}
