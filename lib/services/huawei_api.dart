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
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
    };
    if (_cookie != null) headers['Cookie'] = _cookie!;
    return headers;
  }

  Future<void> _getSession() async {
    final response = await http.get(Uri.parse('$baseUrl/asp/GetRandCount.asp'), headers: _headers());
    if (response.statusCode != 200) throw Exception('Unable to connect to Huawei router (HTTP ${response.statusCode}).');
    _token = response.body.trim();
    if (_token == null || _token!.isEmpty) throw Exception('Huawei router did not return a login token.');
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
      headers: {..._headers(), 'Content-Type': 'application/x-www-form-urlencoded', 'Referer': '$baseUrl/login.asp', 'Origin': baseUrl},
      body: {'UserName': username, 'PassWord': encodedPassword, 'Language': 'english', 'x.X_HW_Token': _token!},
    );
    if (response.statusCode != 200) throw Exception('Huawei login failed (HTTP ${response.statusCode}).');
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final newCookie = _extractCookie(setCookie);
      if (newCookie != null) _cookie = newCookie;
    }
    if (response.body.contains("top.location.replace('/')") || !response.body.contains('login')) return true;
    throw Exception('Huawei login was not accepted. Please check the username and password.');
  }

  Future<String> getPage(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'), headers: _headers());
    if (response.statusCode != 200) throw Exception('Huawei router returned HTTP ${response.statusCode}.');
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
      String vlanId = values[22];
      if (vlanId.isEmpty || vlanId == '0') vlanId = '-';
      String ipAddress = values[13];
      if (ipAddress.isEmpty) ipAddress = '0.0.0.0';
      wanList.add({'domain': values[0], 'wanName': values[7], 'status': values[4], 'ipAddress': ipAddress, 'vlanId': vlanId});
    }
    if (wanList.isEmpty) throw Exception('No usable WAN connection was found.');
    return wanList;
  }

  Future<String> _get2GBasicPage() async {
    final response = await http.get(
      Uri.parse('$baseUrl/html/amp/wlanbasic/WlanBasic.asp?2G'),
      headers: {
        ..._headers(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
        'Referer': '$baseUrl/index.asp',
        'Upgrade-Insecure-Requests': '1',
      },
    );
    if (response.statusCode != 200) throw Exception('2.4 GHz Wi-Fi settings request failed: HTTP ${response.statusCode}');
    return response.body;
  }

  String _inputValue(String body, String name, {String fallback = ''}) {
    final escaped = RegExp.escape(name);
    final patterns = <RegExp>[
      RegExp('<input[^>]+name=["\']$escaped["\'][^>]+value=["\']([^"\']*)["\']', caseSensitive: false),
      RegExp('<input[^>]+value=["\']([^"\']*)["\'][^>]+name=["\']$escaped["\']', caseSensitive: false),
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
      RegExp('<input[^>]+name=["\']$escaped["\'][^>]*checked[^>]*>', caseSensitive: false),
      RegExp('<input[^>]+checked[^>]*name=["\']$escaped["\'][^>]*>', caseSensitive: false),
    ];
    return patterns.any((pattern) => pattern.hasMatch(body)) || fallback;
  }

  String _findPageToken(String body) {
    final patterns = <RegExp>[
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

  Future<HuaweiWifiSettings> get2GWifiSettings() async {
    final body = await _get2GBasicPage();
    return HuaweiWifiSettings(
      enabled: _inputChecked(body, 'y.Enable', fallback: true),
      ssid: _inputValue(body, 'y.SSID', fallback: 'HUAWEI-2.4G'),
      broadcastSsid: _inputChecked(body, 'y.SSIDAdvertisementEnabled', fallback: true),
      wmmEnabled: _inputChecked(body, 'w.WMMEnable', fallback: true),
      maxAssociateNum: int.tryParse(_inputValue(body, 'w.MaxAssociateNum')) ?? 32,
      authenticationMode: 'PSKAuthentication',
      encryptionMode: 'TKIPandAESEncryption',
      groupRekey: int.tryParse(_inputValue(body, 'y.X_HW_GroupRekey')) ?? 3600,
      wpsEnabled: _inputChecked(body, 'z.Enable'),
    );
  }

  Future<void> update2GWifiNameAndPassword({required String ssid, required String password}) async {
    if (_cookie == null) throw Exception('Huawei session is not available. Please log in again.');
    final trimmedSsid = ssid.trim();
    final trimmedPassword = password.trim();
    if (trimmedSsid.isEmpty || trimmedSsid.length > 32) throw Exception('Wi-Fi name must contain 1–32 characters.');
    if (trimmedPassword.length < 8 || trimmedPassword.length > 63) throw Exception('Wi-Fi password must contain 8–63 characters.');

    final page = await _get2GBasicPage();
    final pageToken = _findPageToken(page);
    final token = pageToken.isNotEmpty ? pageToken : (_token ?? '');
    if (token.isEmpty) throw Exception('Huawei Wi-Fi page did not provide a configuration token.');

    final query = <String, String>{
      'w': 'InternetGatewayDevice.X_HW_DEBUG.AMP.WifiCoverSetWlanBasic',
      'y': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1',
      'z': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.WPS',
      'k': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.PreSharedKey.1',
      'RequestFile': 'html/amp/wlanbasic/WlanBasic.asp',
    };
    final uri = Uri.parse('$baseUrl/html/amp/wlanbasic/set.cgi').replace(queryParameters: query);

    final body = <String, String>{
      'y.Enable': '1',
      'y.SSIDAdvertisementEnabled': '1',
      'y.SSID': trimmedSsid,
      'y.BeaconType': 'WPAand11i',
      'y.X_HW_WPAand11iAuthenticationMode': 'PSKAuthentication',
      'y.X_HW_WPAand11iEncryptionModes': 'TKIPandAESEncryption',
      'k.PreSharedKey': trimmedPassword,
      'y.X_HW_GroupRekey': '3600',
      'z.Enable': '0',
      'z.X_HW_ConfigMethod': 'PushButton',
      'w.SsidInst': '1',
      'w.SSID': trimmedSsid,
      'w.Enable': '1',
      'w.Standard': '11bgn',
      'w.BasicAuthenticationMode': 'None',
      'w.BasicEncryptionModes': 'TKIPandAESEncryption',
      'w.WPAAuthenticationMode': 'EAPAuthentication',
      'w.WPAEncryptionModes': 'TKIPandAESEncryption',
      'w.IEEE11iAuthenticationMode': 'EAPAuthentication',
      'w.IEEE11iEncryptionModes': 'TKIPandAESEncryption',
      'w.MixAuthenticationMode': 'PSKAuthentication',
      'w.MixEncryptionModes': 'TKIPandAESEncryption',
      'w.SSIDAdvertisementEnabled': '1',
      'w.WMMEnable': '1',
      'w.MaxAssociateNum': '32',
      'w.BeaconType': 'WPAand11i',
      'w.WEPEncryptionLevel': '104-bit',
      'w.WEPKeyIndex': '1',
      'w.Key': trimmedPassword,
      'x.X_HW_Token': token,
    };

    final response = await http.post(
      uri,
      headers: {
        ..._headers(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'en-GB,en-US;q=0.9,en;q=0.8',
        'Cache-Control': 'max-age=0',
        'Content-Type': 'application/x-www-form-urlencoded',
        'DNT': '1',
        'Origin': baseUrl,
        'Referer': '$baseUrl/html/amp/wlanbasic/WlanBasic.asp?2G',
        'Upgrade-Insecure-Requests': '1',
      },
      body: body,
    );

    if (response.statusCode != 200) throw Exception('Huawei did not accept the Wi-Fi request (HTTP ${response.statusCode}).');
    final responseBody = response.body.toLowerCase();
    if (responseBody.contains('login.asp') && responseBody.contains('username')) throw Exception('Huawei session expired. Please log in again.');

    // Verify the SSID through the same WlanBasic page. telecomadmin masks
    // the current PSK, so password verification by read-back is not possible.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final verifyPage = await _get2GBasicPage();
    final actualSsid = _inputValue(verifyPage, 'y.SSID', fallback: '');
    if (actualSsid.isNotEmpty && actualSsid != trimmedSsid) {
      throw Exception('Huawei did not apply the requested 2.4 GHz Wi-Fi name. Current name is "$actualSsid".');
    }
  }

  Future<void> update2GWifiSettings({required HuaweiWifiSettings settings, String? password}) async {
    final value = password?.trim() ?? '';
    if (value.isEmpty) throw Exception('Enter a new Wi-Fi password before saving.');
    await update2GWifiNameAndPassword(ssid: settings.ssid, password: value);
  }

  Future<HuaweiSimpleWifiSettings> getSimpleWifiSettings() async {
    throw Exception('5 GHz/simple Wi-Fi test is temporarily disabled.');
  }

  Future<void> updateSimpleWifiSettings({required HuaweiSimpleWifiBandSettings band2G, required HuaweiSimpleWifiBandSettings band5G, String? password2G, String? password5G}) async {
    throw Exception('5 GHz/simple Wi-Fi test is temporarily disabled.');
  }

  Future<void> update5GWifiSettings({required HuaweiSimpleWifiBandSettings settings, String? password}) async {
    throw Exception('5 GHz Wi-Fi test is temporarily disabled.');
  }

  String _decodeHtml(String value) {
    return value.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>');
  }

  String _decodeHuaweiValue(String value) {
    return value.replaceAllMapped(RegExp(r'\\x([0-9A-Fa-f]{2})'), (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)));
  }
}