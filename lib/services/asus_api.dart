import 'dart:convert';

import 'package:http/http.dart' as http;

class AsusApi {
  final String baseUrl;

  String? _asusToken;

  AsusApi({
    required this.baseUrl,
  });

  Map<String, String> _baseHeaders() {
    return {
      'Accept': '*/*',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/151.0.0.0 Safari/537.36',
    };
  }

  Future<void> _getLoginPage() async {
    final response = await http.get(
      Uri.parse('$baseUrl/Main_Login.asp'),
      headers: {
        ..._baseHeaders(),
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to open ASUS login page '
        '(HTTP ${response.statusCode}).',
      );
    }

    final setCookie =
        response.headers['set-cookie'];

    if (setCookie != null) {
      final token =
          _extractAsusToken(setCookie);

      if (token != null) {
        _asusToken = token;
      }
    }
  }

  String? _extractAsusToken(
    String cookie,
  ) {
    const key = 'asus_token=';

    final start = cookie.indexOf(key);

    if (start == -1) {
      return null;
    }

    final valueStart =
        start + key.length;

    final end =
        cookie.indexOf(';', valueStart);

    if (end == -1) {
      return cookie.substring(valueStart);
    }

    return cookie.substring(
      valueStart,
      end,
    );
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    /*
     * First establish the ASUSWRT session.
     */
    await _getLoginPage();

    final credentials = base64Encode(
      utf8.encode(
        '$username:$password',
      ),
    );

    final headers = <String, String>{
      ..._baseHeaders(),
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Content-Type':
          'application/x-www-form-urlencoded',
      'Origin': baseUrl,
      'Referer':
          '$baseUrl/Main_Login.asp',
    };

    if (_asusToken != null) {
      headers['Cookie'] =
          'clickedItem_tab=0; '
          'asus_token=$_asusToken';
    }

    final response = await http.post(
      Uri.parse('$baseUrl/login.cgi'),
      headers: headers,
      body: {
        'group_id': '',
        'action_mode': '',
        'action_script': '',
        'action_wait': '5',
        'current_page': 'Main_Login.asp',
        'next_page': 'index.asp',
        'login_authorization':
            credentials,
      },
    );

    final setCookie =
        response.headers['set-cookie'];

    if (setCookie != null) {
      final token =
          _extractAsusToken(setCookie);

      if (token != null) {
        _asusToken = token;
      }
    }

    if (response.statusCode != 200) {
      throw Exception(
        'ASUS login failed '
        '(HTTP ${response.statusCode}).',
      );
    }

    if (response.body.contains(
      "top.location.href='/Main_Login.asp'",
    )) {
      throw Exception(
        'ASUS login failed. '
        'Check username and password.',
      );
    }

    return true;
  }

  Future<String> _get(
    String path,
  ) async {
    final headers = <String, String>{
      ..._baseHeaders(),
      'Accept': '*/*',
      'Referer':
          '$baseUrl/index.asp',
    };

    if (_asusToken != null) {
      headers['Cookie'] =
          'clickedItem_tab=0; '
          'asus_token=$_asusToken';
    }

    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'ASUS router returned HTTP '
        '${response.statusCode}.',
      );
    }

    if (response.body.contains(
      "top.location.href='/Main_Login.asp'",
    )) {
      throw Exception(
        'ASUS session expired. '
        'Please login again.',
      );
    }

    return response.body;
  }

  Future<Map<String, dynamic>>
      getStatus() async {
    final hash =
        DateTime.now()
            .microsecondsSinceEpoch
            .toString();

    final xml = await _get(
      '/ajax_status.xml?hash=$hash',
    );

    return _parseStatusXml(xml);
  }

  Map<String, dynamic> _parseStatusXml(
    String xml,
  ) {
    final result =
        <String, dynamic>{};

    final values =
        <String, String>{};

    final entryRegex = RegExp(
      r'<(\w+)>(.*?)</\1>',
      dotAll: true,
    );

    for (final match
        in entryRegex.allMatches(xml)) {
      final value =
          match.group(2)?.trim() ?? '';

      final equalsIndex =
          value.indexOf('=');

      if (equalsIndex <= 0) {
        continue;
      }

      final key =
          value.substring(
        0,
        equalsIndex,
      );

      final data =
          value.substring(
        equalsIndex + 1,
      );

      values[key] = data;
    }

    result['wan'] = {
      'active_wan_unit':
          values['active_wan_unit'],
      'wan0_enable':
          values['wan0_enable'],
      'wan0_ipaddr':
          values['wan0_ipaddr'],
      'wan0_realip_state':
          values['wan0_realip_state'],
      'link_internet':
          values['link_internet'],
    };

    result['wifi'] = {
      'wifi_hw_switch':
          values['wifi_hw_switch'],
      'wlan0_radio_flag':
          values['wlan0_radio_flag'],
      'wlan1_radio_flag':
          values['wlan1_radio_flag'],
      'wlan2_radio_flag':
          values['wlan2_radio_flag'],
      'data_rate_info_2g':
          values['data_rate_info_2g'],
      'data_rate_info_5g':
          values['data_rate_info_5g'],
      'data_rate_info_5g_2':
          values['data_rate_info_5g_2'],
      'rssi_2g':
          values['rssi_2g'],
      'rssi_5g':
          values['rssi_5g'],
      'rssi_5g_2':
          values['rssi_5g_2'],
    };

    result['system'] = {
      'uptime':
          values['uptimeStr'],
    };

    result['vpn'] = {
      'vpnc_proto':
          values['vpnc_proto'],
      'vpnc_state':
          values['vpnc_state_t'],
    };

    result['usb'] = {
      'devices':
          values['usb'],
    };

    return result;
  }
}