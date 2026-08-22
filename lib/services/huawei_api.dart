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
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/151.0.0.0 Safari/537.36',
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
    throw Exception('Huawei login was not accepted. Please check the username and password.');
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
    if (response.statusCode != 200) {
      throw Exception('WAN request failed: HTTP ${response.statusCode}');
    }
    final body = response.body;
    final wanMatches = RegExp(r'new\s+WanPPP\((.*?)\)', dotAll: true).allMatches(body);
    if (wanMatches.isEmpty) throw Exception('No WAN connection was found.');
    final wanList = <Map<String, String>>[];
    for (final wanMatch in wanMatches) {
      final raw = wanMatch.group(1);
      if (raw == null || raw.isEmpty) continue;
      final values = <String>[];
      final valueRegex = RegExp(r'"((?:\\.|[^"])*)"');
      for (final match in valueRegex.allMatches(raw)) {
        values.add(_decodeHuaweiValue(match.group(1)!));
      }
      if (values.length < 25) continue;
      String vlanId = values[22];
      if (vlanId.isEmpty || vlanId == '0') vlanId = '-';
      String ipAddress = values[13];
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

  // Returns the actual SSID names exposed by Huawei's wlan_list.asp.
  // On this EG8145V5 firmware WLANConfiguration.1 is 2.4 GHz and
  // WLANConfiguration.5 is 5 GHz, but we match the reported RF band too.
  Future<Map<String, String>> getWlanSsidNames() async {
    final response = await http.get(
      Uri.parse('$baseUrl/html/amp/common/wlan_list.asp'),
      headers: {
        ..._headers(),
        'Accept': '*/*',
        'Referer': '$baseUrl/index.asp',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Huawei WLAN list request failed: HTTP ${response.statusCode}');
    }

    final result = <String, String>{};
    final matches = RegExp(
      r'new\s+stWlanInfo\(\s*"((?:\\.|[^"])*)"\s*,\s*"((?:\\.|[^"])*)"\s*,\s*"((?:\\.|[^"])*)"\s*,\s*"((?:\\.|[^"])*)"\s*,\s*"((?:\\.|[^"])*)"\s*,\s*"((?:\\.|[^"])*)"',
      dotAll: true,
    ).allMatches(response.body);

    for (final match in matches) {
      final domain = _decodeHuaweiValue(match.group(1)!);
      final ssid = _decodeHuaweiValue(match.group(3)!);
      final band = _decodeHuaweiValue(match.group(6)!);
      if (ssid.isEmpty) continue;
      if (band == '2.4GHz') result['2.4'] = ssid;
      if (band == '5GHz') result['5'] = ssid;
      if (domain.endsWith('.WLANConfiguration.1')) result['2.4'] = ssid;
      if (domain.endsWith('.WLANConfiguration.5')) result['5'] = ssid;
    }

    return result;
  }

  Future<HuaweiWifiSettings> get2GWifiSettings() async {
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
    final body = response.body;

    String value(String name, {String fallback = ''}) {
      final escaped = RegExp.escape(name);
      final patterns = [
        RegExp('<input[^>]+name=["\']$escaped["\'][^>]+value=["\']([^"\']*)["\']', caseSensitive: false),
        RegExp('<input[^>]+value=["\']([^"\']*)["\'][^>]+name=["\']$escaped["\']', caseSensitive: false),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(body);
        if (match != null) return _decodeHtml(match.group(1) ?? fallback);
      }
      return fallback;
    }

    bool checked(String name, {bool fallback = false}) {
      final escaped = RegExp.escape(name);
      final patterns = [
        RegExp('<input[^>]+name=["\']$escaped["\'][^>]*checked[^>]*>', caseSensitive: false),
        RegExp('<input[^>]+checked[^>]*name=["\']$escaped["\'][^>]*>', caseSensitive: false),
      ];
      return patterns.any((pattern) => pattern.hasMatch(body)) || fallback;
    }

    String selectValue(String name, {String fallback = ''}) {
      final escaped = RegExp.escape(name);
      final select = RegExp(
        '<select[^>]+name=["\']$escaped["\'][^>]*>(.*?)</select>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(body)?.group(1);
      if (select == null) return fallback;
      final selected = RegExp(
        '<option[^>]+value=["\']([^"\']*)["\'][^>]*selected[^>]*>',
        caseSensitive: false,
      ).firstMatch(select);
      return selected == null ? fallback : _decodeHtml(selected.group(1) ?? fallback);
    }

    int intValue(String name, int fallback) => int.tryParse(value(name)) ?? fallback;
    final names = await getWlanSsidNames();

    return HuaweiWifiSettings(
      enabled: checked('y.Enable', fallback: true),
      ssid: names['2.4'] ?? value('y.SSID', fallback: 'HUAWEI-2.4G'),
      broadcastSsid: checked('y.SSIDAdvertisementEnabled', fallback: true),
      wmmEnabled: checked('w.WMMEnable', fallback: true),
      maxAssociateNum: intValue('w.MaxAssociateNum', 32),
      authenticationMode: selectValue('y.X_HW_WPAand11iAuthenticationMode', fallback: 'PSKAuthentication'),
      encryptionMode: selectValue('y.X_HW_WPAand11iEncryptionModes', fallback: 'TKIPandAESEncryption'),
      groupRekey: intValue('y.X_HW_GroupRekey', 3600),
      wpsEnabled: checked('z.Enable'),
    );
  }

  Future<void> update2GWifiSettings({required HuaweiWifiSettings settings, String? password}) async {
    if (_token == null || _cookie == null) {
      throw Exception('Huawei session is not available. Please log in again.');
    }
    final query = <String, String>{
      'w': 'InternetGatewayDevice.X_HW_DEBUG.AMP.WifiCoverSetWlanBasic',
      'y': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1',
      'z': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.WPS',
      'k': 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.PreSharedKey.1',
      'RequestFile': 'html/amp/wlanbasic/WlanBasic.asp',
    };
    final uri = Uri.parse('$baseUrl/html/amp/wlanbasic/set.cgi').replace(queryParameters: query);
    final body = <String, String>{
      'y.Enable': settings.enabled ? '1' : '0',
      'y.SSIDAdvertisementEnabled': settings.broadcastSsid ? '1' : '0',
      'y.SSID': settings.ssid,
      'y.BeaconType': 'WPAand11i',
      'y.X_HW_WPAand11iAuthenticationMode': settings.authenticationMode,
      'y.X_HW_WPAand11iEncryptionModes': settings.encryptionMode,
      'y.X_HW_GroupRekey': settings.groupRekey.toString(),
      'z.Enable': settings.wpsEnabled ? '1' : '0',
      'z.X_HW_ConfigMethod': 'PushButton',
      'w.SsidInst': '1',
      'w.SSID': settings.ssid,
      'w.Enable': settings.enabled ? '1' : '0',
      'w.Standard': '11bgn',
      'w.BasicAuthenticationMode': 'None',
      'w.BasicEncryptionModes': 'TKIPandAESEncryption',
      'w.WPAAuthenticationMode': 'EAPAuthentication',
      'w.WPAEncryptionModes': 'TKIPandAESEncryption',
      'w.IEEE11iAuthenticationMode': 'EAPAuthentication',
      'w.IEEE11iEncryptionModes': 'TKIPandAESEncryption',
      'w.MixAuthenticationMode': 'PSKAuthentication',
      'w.MixEncryptionModes': 'TKIPandAESEncryption',
      'w.SSIDAdvertisementEnabled': settings.broadcastSsid ? '1' : '0',
      'w.WMMEnable': settings.wmmEnabled ? '1' : '0',
      'w.MaxAssociateNum': settings.maxAssociateNum.toString(),
      'w.BeaconType': 'WPAand11i',
      'w.WEPEncryptionLevel': '104-bit',
      'w.WEPKeyIndex': '1',
      'x.X_HW_Token': _token!,
    };
    final trimmedPassword = password?.trim() ?? '';
    if (trimmedPassword.isNotEmpty) {
      body['k.PreSharedKey'] = trimmedPassword;
      body['w.Key'] = trimmedPassword;
    }
    final response = await http.post(
      uri,
      headers: {
        ..._headers(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/html/amp/wlanbasic/WlanBasic.asp?2G',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to save 2.4 GHz Wi-Fi settings (HTTP ${response.statusCode}).');
    }
    final responseBody = response.body.toLowerCase();
    if (responseBody.contains('login.asp') && responseBody.contains('username')) {
      throw Exception('Huawei session expired. Please log in again.');
    }
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
      final patterns = [
        RegExp('<input[^>]+name=["\']$escaped["\'][^>]+value=["\']([^"\']*)["\']', caseSensitive: false),
        RegExp('<input[^>]+value=["\']([^"\']*)["\'][^>]+name=["\']$escaped["\']', caseSensitive: false),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(body);
        if (match != null) return _decodeHtml(match.group(1) ?? fallback);
      }
      return fallback;
    }

    bool checked(String name, {bool fallback = false}) {
      final escaped = RegExp.escape(name);
      final patterns = [
        RegExp('<input[^>]+name=["\']$escaped["\'][^>]*checked[^>]*>', caseSensitive: false),
        RegExp('<input[^>]+checked[^>]*name=["\']$escaped["\'][^>]*>', caseSensitive: false),
      ];
      return patterns.any((pattern) => pattern.hasMatch(body)) || fallback;
    }

    int intValue(String name, int fallback) => int.tryParse(value(name)) ?? fallback;
    final names = await getWlanSsidNames();

    return HuaweiSimpleWifiSettings(
      band2G: HuaweiSimpleWifiBandSettings(
        enabled: checked('m.Enable', fallback: true),
        ssid: names['2.4'] ?? value('w0.SSID', fallback: 'HUAWEI-2.4G'),
        broadcastSsid: checked('w0.SSIDAdvertisementEnabled', fallback: true),
        wmmEnabled: checked('m.WMMEnable', fallback: true),
        staIsolation: checked('m.STAIsolation'),
        maxAssociateNum: intValue('m.MaxAssociateNum', 32),
      ),
      band5G: HuaweiSimpleWifiBandSettings(
        enabled: checked('m.Enable5G', fallback: true),
        ssid: names['5'] ?? value('w1.SSID', fallback: 'HUAWEI-5G'),
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
    final uri = Uri.parse('$baseUrl/html/amp/wlanbasic/set.cgi').replace(queryParameters: query);
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
      'x.X_HW_Token': _token!,
    };
    final trimmed2G = password2G?.trim() ?? '';
    final trimmed5G = password5G?.trim() ?? '';
    if (trimmed2G.isNotEmpty) {
      body['m.Key'] = trimmed2G;
    }
    if (trimmed5G.isNotEmpty) {
      body['psk1.PreSharedKey'] = trimmed5G;
      body['m.Key5G'] = trimmed5G;
    }
    final response = await http.post(
      uri,
      headers: {
        ..._headers(),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer': '$baseUrl/html/amp/wlanbasic/simplewificfg.asp',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to save Wi-Fi settings (HTTP ${response.statusCode}).');
    }
    final responseBody = response.body.toLowerCase();
    if (responseBody.contains('login.asp') && responseBody.contains('username')) {
      throw Exception('Huawei session expired. Please log in again.');
    }
  }

  Future<void> update5GWifiSettings({
    required HuaweiSimpleWifiBandSettings settings,
    String? password,
  }) async {
    final current = await getSimpleWifiSettings();
    await updateSimpleWifiSettings(
      band2G: current.band2G,
      band5G: settings,
      password5G: password,
    );
  }

  String _decodeHuaweiValue(String value) {
    return value
        .replaceAll(r'\x3a', ':')
        .replaceAll(r'\x5f', '_')
        .replaceAll(r'\x2e', '.')
        .replaceAll(r'\x2d', '-')
        .replaceAll(r'\x5c', r'\')
        .replaceAll(r'\"', '"');
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
