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
      throw Exception('Unable to connect to Huawei router (HTTP ${response.statusCode}).');
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
      final newCookie = _extractCookie(setCookie);
      if (newCookie != null) _cookie = newCookie;
    }
    if (response.body.contains("top.location.replace('/')") ||
        !response.body.contains('login')) {
      return true;
    }
    throw Exception('Huawei login was not accepted. Please check the username and password.');
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
      throw Exception('Unable to obtain the current Huawei session token before logout (HTTP ${pageResponse.statusCode}).');
    }
    final token = _getOntToken(pageResponse.body);
    final response = await http.post(
      Uri.parse('$baseUrl/logout.cgi').replace(
        queryParameters: {'RequestFile': 'html/logout.html'},
      ),
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
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _headers());
    if (response.statusCode != 200) {
      throw Exception('Huawei router returned HTTP ${response.statusCode}.');
    }
    return response.body;
  }

  Future<List<Map<String, String>>> getWanStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/html/bbsp/common/getwanlist.asp?${DateTime.now().millisecondsSinceEpoch}'),
      headers: {..._headers(), 'Referer': '$baseUrl/html/bbsp/waninfo/waninfo.asp'},
    );
    if (response.statusCode != 200) throw Exception('WAN request failed: HTTP ${response.statusCode}');
    final wanMatches = RegExp(r'new\s+WanPPP\((.*?)\)', dotAll: true).allMatches(response.body);
    if (wanMatches.isEmpty) throw Exception('No WAN connection was found.');
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
    if (wanList.isEmpty) throw Exception('No usable WAN connection was found.');
    return wanList;
  }

  Future<String> _get2GBasicPage() async {
    final response = await http.get(
      Uri.parse('$baseUrl/html/amp/wlanbasic/WlanBasic.asp?2G'),
      headers: {
        ..._headers(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': '$baseUrl/index.asp',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('2.4 GHz Wi-Fi settings request failed: HTTP ${response.statusCode}');
    }
    return response.body;
  }

  String _inputValue(String body, String name, {String fallback = ''}) {
    final escaped = RegExp.escape(name);
    final patterns = <RegExp>[
      RegExp('<input[^>]+name=["\\\']$escaped["\\\'][^>]+value=["\\\']([^"\\\']*)["\\\']', caseSensitive: false),
      RegExp('<input[^>]+value=["\\\']([^"\\\']*)["\\\'][^>]+name=["\\\']$escaped["\\\']', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) return _decodeHtml(match.group(1) ?? fallback);
    }
    return fallback;
  }

  bool _inputChecked(String body, String name, {bool fallback = false}) {
    final escaped = RegExp.escape(name);
    final patterns = <RegExp>[
      RegExp('<input[^>]+name=["\\\']$escaped["\\\'][^>]*checked[^>]*>', caseSensitive: false),
      RegExp('<input[^>]+checked[^>]*name=["\\\']$escaped["\\\'][^>]*>', caseSensitive: false),
    ];
    return patterns.any((pattern) => pattern.hasMatch(body)) || fallback;
  }

  String _getOntToken(String body) {
    final patterns = <RegExp>[
      RegExp(r'''<input[^>]*name\s*=\s*["']onttoken["'][^>]*value\s*=\s*["']([^"']+)["']''', caseSensitive: false),
      RegExp(r'''<input[^>]*value\s*=\s*["']([^"']+)["'][^>]*name\s*=\s*["']onttoken["']''', caseSensitive: false),
      RegExp(r'''(?:id|name)\s*:\s*["']onttoken["'][^}]*?value\s*:\s*["']([^"']+)["']''', caseSensitive: false, dotAll: true),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final token = match.group(1)?.trim() ?? '';
        if (token.isNotEmpty) return _decodeHtml(token);
      }
    }
    throw Exception('Huawei page did not provide onttoken.');
  }

  String _get2GSsidFromPage(String body) {
    final direct = _inputValue(body, 'y.SSID').trim();
    if (direct.isNotEmpty && direct.toLowerCase() != 'undefined') return direct;

    for (final field in ['w1Ssid', 'w1SSID']) {
      final value = _inputValue(body, field).trim();
      if (value.isNotEmpty && value.toLowerCase() != 'undefined') return value;
    }

    final match = RegExp(
      r'''new\s+stWlanWifi\s*\(\s*"((?:\\.|[^"])*)"\s*,\s*"ath0"\s*,\s*"((?:\\.|[^"])*)"\s*,\s*"((?:\\.|[^"])*)"''',
      dotAll: true,
    ).firstMatch(body);
    if (match != null) {
      final domain = _decodeHuaweiValue(match.group(1)!);
      final ssid = _decodeHuaweiValue(match.group(3)!).trim();
      if (domain.endsWith('WLANConfiguration.1') && ssid.isNotEmpty) return ssid;
    }
    throw Exception('Huawei 2.4 GHz page did not expose the current Wi-Fi name.');
  }

  Future<HuaweiWifiSettings> get2GWifiSettings() async {
    final body = await _get2GBasicPage();
    return HuaweiWifiSettings(
      enabled: _inputChecked(body, 'y.Enable', fallback: true),
      ssid: _get2GSsidFromPage(body),
      broadcastSsid: _inputChecked(body, 'y.SSIDAdvertisementEnabled', fallback: true),
      wmmEnabled: _inputChecked(body, 'w.WMMEnable', fallback: true),
      maxAssociateNum: int.tryParse(_inputValue(body, 'w.MaxAssociateNum')) ?? 32,
      authenticationMode: 'PSKAuthentication',
      encryptionMode: 'TKIPandAESEncryption',
      groupRekey: int.tryParse(_inputValue(body, 'y.X_HW_GroupRekey')) ?? 3600,
      wpsEnabled: _inputChecked(body, 'z.Enable'),
    );
  }

  /// Restored dedicated 2.4 GHz WlanBasic save flow based on the captured
  /// EG8145V5 browser request. This intentionally does not use the dual-band
  /// simplewificfg save path, so WLANConfiguration.5 remains untouched.
  Future<void> update2GWifiNameAndPassword({
    required String ssid,
    required String password,
  }) async {
    if (_token == null || _cookie == null) {
      throw Exception('Huawei session is not available. Please log in again.');
    }

    final trimmedSsid = ssid.trim();
    final trimmedPassword = password.trim();
    if (trimmedSsid.isEmpty) throw Exception('Wi-Fi name cannot be empty.');
    if (trimmedPassword.length < 8 || trimmedPassword.length > 63) {
      throw Exception('Wi-Fi password must be 8–63 characters.');
    }

    final page = await _get2GBasicPage();
    final pageToken = _findPageToken(page);
    if (pageToken.isEmpty) {
      throw Exception('Huawei 2.4 GHz page did not provide a save token.');
    }

    final query = <String, String>{
      'w': 'InternetGatewayDevice.X_HW_DEBUG.AMP.WifiCoverSetWlanBasic',
      'y': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1',
      'z': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.WPS',
      'k': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.PreSharedKey.1',
      'RequestFile': 'html/amp/wlanbasic/WlanBasic.asp',
    };

    final body = <String, String>{
      'y.Enable': _inputChecked(page, 'y.Enable', fallback: true) ? '1' : '0',
      'y.SSIDAdvertisementEnabled':
          _inputChecked(page, 'y.SSIDAdvertisementEnabled', fallback: true) ? '1' : '0',
      'y.SSID': trimmedSsid,
      'y.BeaconType': _inputValue(page, 'y.BeaconType', fallback: 'WPAand11i'),
      'y.X_HW_WPAand11iAuthenticationMode': _inputValue(
        page,
        'y.X_HW_WPAand11iAuthenticationMode',
        fallback: 'PSKAuthentication',
      ),
      'y.X_HW_WPAand11iEncryptionModes': _inputValue(
        page,
        'y.X_HW_WPAand11iEncryptionModes',
        fallback: 'TKIPandAESEncryption',
      ),
      'k.PreSharedKey': trimmedPassword,
      'y.X_HW_GroupRekey': _inputValue(page, 'y.X_HW_GroupRekey', fallback: '3600'),
      'z.Enable': _inputChecked(page, 'z.Enable') ? '1' : '0',
      'z.X_HW_ConfigMethod': _inputValue(page, 'z.X_HW_ConfigMethod', fallback: 'PushButton'),
      'w.SsidInst': _inputValue(page, 'w.SsidInst', fallback: '1'),
      'w.SSID': trimmedSsid,
      'w.Enable': _inputChecked(page, 'w.Enable', fallback: true) ? '1' : '0',
      'w.Standard': _inputValue(page, 'w.Standard', fallback: '11bgn'),
      'w.BasicAuthenticationMode': _inputValue(page, 'w.BasicAuthenticationMode', fallback: 'None'),
      'w.BasicEncryptionModes': _inputValue(page, 'w.BasicEncryptionModes', fallback: 'TKIPandAESEncryption'),
      'w.WPAAuthenticationMode': _inputValue(page, 'w.WPAAuthenticationMode', fallback: 'EAPAuthentication'),
      'w.WPAEncryptionModes': _inputValue(page, 'w.WPAEncryptionModes', fallback: 'TKIPandAESEncryption'),
      'w.IEEE11iAuthenticationMode': _inputValue(page, 'w.IEEE11iAuthenticationMode', fallback: 'EAPAuthentication'),
      'w.IEEE11iEncryptionModes': _inputValue(page, 'w.IEEE11iEncryptionModes', fallback: 'TKIPandAESEncryption'),
      'w.MixAuthenticationMode': _inputValue(page, 'w.MixAuthenticationMode', fallback: 'PSKAuthentication'),
      'w.MixEncryptionModes': _inputValue(page, 'w.MixEncryptionModes', fallback: 'TKIPandAESEncryption'),
      'w.SSIDAdvertisementEnabled':
          _inputChecked(page, 'w.SSIDAdvertisementEnabled', fallback: true) ? '1' : '0',
      'w.WMMEnable': _inputChecked(page, 'w.WMMEnable', fallback: true) ? '1' : '0',
      'w.MaxAssociateNum': _inputValue(page, 'w.MaxAssociateNum', fallback: '32'),
      'w.BeaconType': _inputValue(page, 'w.BeaconType', fallback: 'WPAand11i'),
      'w.WEPEncryptionLevel': _inputValue(page, 'w.WEPEncryptionLevel', fallback: '104-bit'),
      'w.WEPKeyIndex': _inputValue(page, 'w.WEPKeyIndex', fallback: '1'),
      'w.Key': trimmedPassword,
      'x.X_HW_Token': pageToken,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/html/amp/wlanbasic/set.cgi').replace(queryParameters: query),
      headers: {
        ..._headers(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/html/amp/wlanbasic/WlanBasic.asp?2G',
        'Upgrade-Insecure-Requests': '1',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Huawei 2.4 GHz Wi-Fi save failed: HTTP ${response.statusCode}');
    }

    final responseBody = response.body;
    if (responseBody.toLowerCase().contains('login') &&
        !responseBody.contains('top.location.replace')) {
      throw Exception('Huawei session expired while saving 2.4 GHz Wi-Fi settings.');
    }
  }

  Future<void> update2GWifiSettings({
    required HuaweiWifiSettings settings,
    String? password,
  }) async {
    final effectivePassword = password?.trim() ?? '';
    if (effectivePassword.isEmpty) {
      throw Exception('Enter the new Wi-Fi password to save the 2.4 GHz network.');
    }
    await update2GWifiNameAndPassword(
      ssid: settings.ssid,
      password: effectivePassword,
    );
  }

  Future<HuaweiSimpleWifiSettings> getSimpleWifiSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/html/amp/wlanbasic/simplewificfg.asp'),
      headers: {
        ..._headers(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': '$baseUrl/index.asp',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Wi-Fi configuration request failed: HTTP ${response.statusCode}');
    }
    final body = response.body;

    String value(String name, {String fallback = ''}) {
      final escaped = RegExp.escape(name);
      final patterns = <RegExp>[
        RegExp('<input[^>]+name=["\\\']$escaped["\\\'][^>]+value=["\\\']([^"\\\']*)["\\\']', caseSensitive: false),
        RegExp('<input[^>]+value=["\\\']([^"\\\']*)["\\\'][^>]+name=["\\\']$escaped["\\\']', caseSensitive: false),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(body);
        if (match != null) return _decodeHtml(match.group(1) ?? fallback);
      }
      return fallback;
    }

    bool checked(String name, {bool fallback = false}) {
      final escaped = RegExp.escape(name);
      final patterns = <RegExp>[
        RegExp('<input[^>]+name=["\\\']$escaped["\\\'][^>]*checked[^>]*>', caseSensitive: false),
        RegExp('<input[^>]+checked[^>]*name=["\\\']$escaped["\\\'][^>]*>', caseSensitive: false),
      ];
      return patterns.any((pattern) => pattern.hasMatch(body)) || fallback;
    }

    int intValue(String name, int fallback) => int.tryParse(value(name)) ?? fallback;

    return HuaweiSimpleWifiSettings(
      band2G: HuaweiSimpleWifiBandSettings(
        enabled: checked('m.Enable', fallback: true),
        ssid: value('w0.SSID', fallback: 'HUAWEI-2.4G'),
        broadcastSsid: checked('w0.SSIDAdvertisementEnabled', fallback: true),
        wmmEnabled: checked('m.WMMEnable', fallback: true),
        staIsolation: checked('m.STAIsolation'),
        maxAssociateNum: intValue('m.MaxAssociateNum', 32),
      ),
      band5G: HuaweiSimpleWifiBandSettings(
        enabled: checked('m.Enable5G', fallback: true),
        ssid: value('w1.SSID', fallback: 'HUAWEI-5G'),
        broadcastSsid: checked('w1.SSIDAdvertisementEnabled', fallback: true),
        wmmEnabled: checked('m.WMMEnable5G', fallback: true),
        staIsolation: checked('m.STAIsolation5G'),
        maxAssociateNum: intValue('m.MaxAssociateNum5G', 32),
      ),
    );
  }

  Future<void> updateSimpleWifiSettings({
    required HuaweiSimpleWifiBandSettings band2G,
    required HuaweiSimpleWifiBandSettings band5G,
    String? password2G,
    String? password5G,
  }) async {
    if (_token == null || _cookie == null) {
      throw Exception('Huawei session is not available. Please log in again.');
    }

    final query = <String, String>{
      'm': 'InternetGatewayDevice.X_HW_DEBUG.AMP.WifiCoverSetWlanBasic',
      'w0': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1',
      'psk1': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.5.PreSharedKey.1',
      'w1': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.5',
      'RequestFile': 'html/amp/wlanbasic/simplewificfg.asp',
    };

    final body = <String, String>{
      'w0.SSID': band2G.ssid,
      'w0.SSIDAdvertisementEnabled': band2G.broadcastSsid ? '1' : '0',
      'm.SSID': band2G.ssid,
      'm.SSIDAdvertisementEnabled': band2G.broadcastSsid ? '1' : '0',
      'm.SsidInst': '1',
      'm.Enable': band2G.enabled ? '1' : '0',
      'm.WMMEnable': band2G.wmmEnabled ? '1' : '0',
      'm.STAIsolation': band2G.staIsolation ? '1' : '0',
      'm.MaxAssociateNum': band2G.maxAssociateNum.toString(),
      'w1.SSID': band5G.ssid,
      'w1.SSIDAdvertisementEnabled': band5G.broadcastSsid ? '1' : '0',
      'm.SSID5G': band5G.ssid,
      'm.SSIDAdvertisementEnabled5G': band5G.broadcastSsid ? '1' : '0',
      'm.SsidInst5G': '5',
      'm.Enable5G': band5G.enabled ? '1' : '0',
      'm.WMMEnable5G': band5G.wmmEnabled ? '1' : '0',
      'm.STAIsolation5G': band5G.staIsolation ? '1' : '0',
      'm.MaxAssociateNum5G': band5G.maxAssociateNum.toString(),
    };

    if (password2G != null && password2G.trim().isNotEmpty) {
      body['psk1.PreSharedKey'] = password2G.trim();
      body['m.Key'] = password2G.trim();
    }
    if (password5G != null && password5G.trim().isNotEmpty) {
      body['psk5.PreSharedKey'] = password5G.trim();
      body['m.Key5G'] = password5G.trim();
    }

    final tokenPage = await getPage('/html/amp/wlanbasic/simplewificfg.asp');
    body['x.X_HW_Token'] = _findPageToken(tokenPage);

    final response = await http.post(
      Uri.parse('$baseUrl/html/amp/wlanbasic/set.cgi').replace(queryParameters: query),
      headers: {
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/html/amp/wlanbasic/simplewificfg.asp',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Wi-Fi settings save failed: HTTP ${response.statusCode}');
    }
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String _decodeHuaweiValue(String value) {
    return value
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\');
  }

  String _findPageToken(String body) {
    final patterns = [
      RegExp(r'name=["\']x\.X_HW_Token["\'][^>]+value=["\']([^"\']+)["\']', caseSensitive: false),
      RegExp(r'value=["\']([^"\']+)["\'][^>]+name=["\']x\.X_HW_Token["\']', caseSensitive: false),
      RegExp(r'x\.X_HW_Token\s*=\s*["\']([^"\']+)["\']', caseSensitive: false),
      RegExp(r'X_HW_Token["\']?\s*[,=:]\s*["\']([^"\']+)["\']', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null && (match.group(1) ?? '').isNotEmpty) return match.group(1)!;
    }
    return '';
  }
}
