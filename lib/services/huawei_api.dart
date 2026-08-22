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

  /*
   * Huawei returns something similar to:
   *
   * var PPPWanList = new Array(
   *   new WanPPP("...", "...", ...),
   *   new WanPPP("...", "...", ...),
   *   null
   * );
   *
   * We must read ALL WanPPP objects.
   */

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

    /*
     * Extract quoted JavaScript values.
     */
    final valueRegex = RegExp(
      r'"((?:\\.|[^"])*)"',
    );

    for (final match
        in valueRegex.allMatches(raw)) {
      values.add(
        _decodeHuaweiValue(
          match.group(1)!,
        ),
      );
    }

    /*
     * WanPPP contains considerably more than
     * the four values we need, but make sure
     * the important fields exist.
     */
    if (values.length < 25) {
      continue;
    }

    /*
     * Huawei WanPPP field positions:
     *
     * 0  = domain
     * 2  = ConnectionTrigger
     * 3  = MACAddress
     * 4  = Status
     * 7  = Name
     * 13 = IPAddress
     * 22 = VlanId
     *
     * These positions come from the Huawei
     * WanPPP() definition captured from the
     * router.
     */

    String vlanId = values[22];

    /*
     * Huawei represents an untagged WAN as
     * VLAN 0. Display '-' instead because the
     * app is showing the user's requested
     * VLAN ID rather than the internal value.
     */
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

  // ============================================================
  // ADD PPPoE WAN
  // ============================================================

  Future<bool> addPppoeWan({
    required String username,
    required String password,
    bool enableVlan = false,
    int vlanId = 0,
    int priority = 0,
    int mtu = 1492,
    List<String> lanBindings = const [],
    List<String> ssidBindings = const ['SSID1'],
  }) async {
    if (_token == null || _cookie == null) {
      throw Exception(
        'Huawei router is not logged in.',
      );
    }

    if (username.trim().isEmpty) {
      throw Exception(
        'PPPoE username is required.',
      );
    }

    if (password.isEmpty) {
      throw Exception(
        'PPPoE password is required.',
      );
    }

    if (enableVlan &&
        (vlanId < 1 || vlanId > 4094)) {
      throw Exception(
        'VLAN ID must be between 1 and 4094.',
      );
    }

    if (priority < 0 || priority > 7) {
      throw Exception(
        '802.1p priority must be between 0 and 7.',
      );
    }

    if (mtu < 576 || mtu > 1492) {
      throw Exception(
        'MTU must be between 576 and 1492.',
      );
    }

    /*
     * Huawei's X_HW_BindPhyPortInfo accepts a
     * binding string. The browser request we
     * captured used:
     *
     *     SSID1
     *
     * We therefore construct the binding from
     * the selected LAN/SSID interfaces.
     *
     * If nothing is selected, we use SSID1,
     * matching the Huawei form's normal default.
     */
    final bindings = <String>[
      ...lanBindings,
      ...ssidBindings,
    ];

    final bindPhyPortInfo = bindings.isEmpty
        ? 'SSID1'
        : bindings.join(',');

    /*
     * Huawei uses 0 when VLAN is disabled
     * in the captured WAN configuration.
     */
    final effectiveVlan =
        enableVlan ? vlanId : 0;

    final uri = Uri.parse(
      '$baseUrl/html/bbsp/wan/addcfg.cgi'
      '?GROUP_a_x='
      'InternetGatewayDevice.WANDevice.1.'
      'WANConnectionDevice'
      '&GROUP_a_y=GROUP_a_x.WANPPPConnection'
      '&RequestFile='
      'html/bbsp/wan/confirmwancfginfo.html',
    );

    final body = <String, String>{
      'GROUP_a_y.Enable': '1',

      'GROUP_a_y.X_HW_IPv4Enable': '1',
      'GROUP_a_y.X_HW_IPv6Enable': '0',
      'GROUP_a_y.X_HW_IPv6MultiCastVLAN': '-1',

      'GROUP_a_y.X_HW_SERVICELIST': 'INTERNET',
      'GROUP_a_y.X_HW_ExServiceList': '',

      'GROUP_a_y.X_HW_VLAN':
          effectiveVlan.toString(),

      'GROUP_a_y.X_HW_PRI':
          priority.toString(),

      'GROUP_a_y.X_HW_PriPolicy':
          'Specified',

      'GROUP_a_y.X_HW_DefaultPri':
          priority.toString(),

      'GROUP_a_y.ConnectionType':
          'IP_Routed',

      'GROUP_a_y.X_HW_MultiCastVLAN':
          '4294967295',

      'GROUP_a_y.NATEnabled': '1',

      'GROUP_a_y.X_HW_NatType': '0',

      'GROUP_a_y.Username':
          username.trim(),

      'GROUP_a_y.Password':
          password,

      'GROUP_a_y.X_HW_LcpEchoReqCheck':
          '0',

      'GROUP_a_y.ConnectionTrigger':
          'AlwaysOn',

      'GROUP_a_y.DNSEnabled': '1',

      'GROUP_a_y.MaxMRUSize':
          mtu.toString(),

      'GROUP_a_y.DNSOverrideAllowed':
          '0',

      'GROUP_a_y.DNSServers': '',

      'GROUP_a_y.X_HW_BindPhyPortInfo':
          bindPhyPortInfo,

      'x.X_HW_Token': _token!,
    };

    final response = await http.post(
      uri,
      headers: {
        ..._headers(),
        'Content-Type':
            'application/x-www-form-urlencoded',
        'Origin': baseUrl,
        'Referer':
            '$baseUrl/html/bbsp/wan/wan.asp',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to add PPPoE WAN. '
        'HTTP ${response.statusCode}.',
      );
    }

    /*
     * Huawei may return a confirmation page or
     * redirect after accepting the configuration.
     *
     * We don't treat the HTML itself as the
     * source of truth. The caller will refresh
     * the WAN list afterward.
     */
    return true;
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