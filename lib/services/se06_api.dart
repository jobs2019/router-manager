import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Se06Api {
  final String routerIp;

  String? sid;

  Se06Api({
    this.routerIp = '192.168.100.1',
  });

  Uri get _apiUrl => Uri.parse('http://$routerIp/api');

  String _encodePassword(String password) {
    return base64Encode(utf8.encode(password));
  }

  Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final body = {
      'version': '1.0',
      'sid': '00000000000000000000000000000000',
      'mid': 0,
      'module': 'login',
      'api': 'login',
      'param': {
        'password': _encodePassword(password),
      },
    };

    final response = await http.post(
      _apiUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Router returned HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data['errcode'] != 0) {
      throw Exception(
        'Router login failed: ${data['errcode']}',
      );
    }

    sid = data['result']['sid'];

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> dashboard() async {
    _requireLogin();

    final body = {
      'version': '1.0',
      'sid': sid,
      'module': 'dashboard',
      'api': 'web',
      'mid': 0,
    };

    final response = await http.post(
      _apiUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Dashboard request failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    return Map<String, dynamic>.from(data);
  }

Future<Map<String, dynamic>> getWifi() async {
  _requireLogin();

  final body = {
    'version': '1.0',
    'sid': sid,
    'module': 'wifi',
    'api': 'get_lede',
    'mid': 0,
  };

  final response = await http.post(
    _apiUrl,
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Wi-Fi request failed: ${response.statusCode}',
    );
  }

  final data = jsonDecode(response.body);

  debugPrint(
    'GET WIFI RESPONSE: ${jsonEncode(data)}',
  );

  return Map<String, dynamic>.from(data);
}

  Future<Map<String, dynamic>> getDevices() async {
    _requireLogin();

    final body = {
      'version': '1.0',
      'sid': sid,
      'module': 'ntraffic',
      'api': 'get_devices',
      'mid': 0,
    };

    final response = await http.post(
      _apiUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Device request failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    debugPrint(
      'GET DEVICES RESPONSE: ${jsonEncode(data)}',
    );

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> setWifi({
    required String ssid,
    required String password,
  }) async {
    _requireLogin();

    final body = {
      'version': '1.0',
      'sid': sid,
      'mid': 0,
      'module': 'wifi',
      'api': 'set_lede',
      'param': {
        'master': {
          'disabled': 0,
          'hidden': 0,
          'ssid': ssid,
          'encryption': 'mixed-psk',
          'key': password,
        },
        'masterac': {
          'disabled': 0,
          'hidden': 0,
          'ssid': ssid,
          'encryption': 'mixed-psk',
          'key': password,
        },
        'radio0': {
          'channel': 0,
          'bw': 'auto',
          'wifi6': '1',
          'maxsta': 128,
        },
        'radio1': {
          'channel': 0,
          'bw': 'auto',
          'wifi6': '1',
          'maxsta': 128,
        },
      },
    };

    final response = await http.post(
      _apiUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Wi-Fi request failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    return Map<String, dynamic>.from(data);
  }

  void _requireLogin() {
    if (sid == null || sid!.isEmpty) {
      throw Exception('Not logged in to router');
    }
  }
}