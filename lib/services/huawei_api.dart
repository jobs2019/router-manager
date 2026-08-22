import 'dart:convert';

import 'package:http/http.dart' as http;

class HuaweiApi {
  final String baseUrl;

  String? _token;
  String? _cookie;

  HuaweiApi({
    required this.baseUrl,
  });

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Accept': '*/*',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/151.0.0.0 Safari/537.36',
    };

    if (_cookie != null) {
      headers['Cookie'] = _cookie!;
    }

    return headers;
  }

  Future<void> _getSession() async {
    final response = await http.get(
      Uri.parse('$baseUrl/asp/GetRandCount.asp'),
      headers: _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to connect to Huawei router '
        '(HTTP ${response.statusCode}).',
      );
    }

    _token = response.body.trim();

    if (_token == null || _token!.isEmpty) {
      throw Exception(
        'Huawei router did not return a login token.',
      );
    }

    final setCookie = response.headers['set-cookie'];

    if (setCookie != null) {
      _cookie = _extractCookie(setCookie);
    }
  }

  String? _extractCookie(String value) {
    final first = value.split(';').first.trim();

    if (first.isEmpty) {
      return null;
    }

    return first;
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    await _getSession();

    final encodedPassword = base64Encode(
      utf8.encode(password),
    );

    final headers = <String, String>{
      ..._headers(),
      'Content-Type':
          'application/x-www-form-urlencoded',
      'Referer':
          '$baseUrl/login.asp',
      'Origin': baseUrl,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/login.cgi'),
      headers: headers,
      body: {
        'UserName': username,
        'PassWord': encodedPassword,
        'Language': 'english',
        'x.X_HW_Token': _token!,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Huawei login failed '
        '(HTTP ${response.statusCode}).',
      );
    }

    final setCookie = response.headers['set-cookie'];

    if (setCookie != null) {
      final newCookie = _extractCookie(setCookie);

      if (newCookie != null) {
        _cookie = newCookie;
      }
    }

    if (response.body.contains(
      "top.location.replace('/')",
    )) {
      return true;
    }

    if (!response.body.contains('login')) {
      return true;
    }

    throw Exception(
      'Huawei login was not accepted. '
      'Please check the username and password.',
    );
  }

  Future<String> getPage(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Huawei router returned HTTP '
        '${response.statusCode}.',
      );
    }

    return response.body;
  }

  // ============================================================
  // WAN INFORMATION
  // ============================================================

  Future<List<Map<String, String>>> getWanStatus() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/html/bbsp/common/getwanlist.asp?'
        '${DateTime.now().millisecondsSinceEpoch}',
      ),
      headers: {
        ..._headers(),
        'Referer':
            '$baseUrl/html/bbsp/waninfo/waninfo.asp',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'WAN request failed: HTTP '
        '${response.statusCode}',
      );
    }

    final body = response.body;

    final wanMatches = RegExp(
      r'new\s+WanPPP\((.*?)\)',
      dotAll: true,
    ).allMatches(body);

    if (wanMatches.isEmpty) {
      throw Exception(
        'No WAN connection was found.',
      );
    }

    final wanList = <Map<String, String>>[];

    for (final wanMatch in wanMatches) {
      final raw = wanMatch.group(1);

      if (raw == null || raw.isEmpty) {
        continue;
      }

      final values = <String>[];

      final valueRegex = RegExp(
        r'"((?:\\.|[^"])*)"',
      );

      for (final match in valueRegex.allMatches(raw)) {
        values.add(
          _decodeHuaweiValue(
            match.group(1)!,
          ),
        );
      }

      if (values.length < 25) {
        continue;
      }

      String vlanId = values[22];

      if (vlanId.isEmpty || vlanId == '0') {
        vlanId = '-';
      }

      String ipAddress = values[13];

      if (ipAddress.isEmpty) {
        ipAddress = '0.0.0.0';
      }

      wanList.add({
        'domain': values[0],
        'wanName': values[7],
        'status': values[4],
        'ipAddress': ipAddress,
        'vlanId': vlanId,
      });
    }

    if (wanList.isEmpty) {
      throw Exception(
        'No usable WAN connection was found.',
      );
    }

    return wanList;
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
}
