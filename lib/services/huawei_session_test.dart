import 'dart:convert';

import 'package:http/http.dart' as http;

class HuaweiSessionTestResult {
  final bool loginSuccess;
  final bool sidFound;
  final bool tokenFound;
  final int loginStatus;
  final int pageStatus;
  final int sidLength;
  final int tokenLength;
  final String message;

  const HuaweiSessionTestResult({
    required this.loginSuccess,
    required this.sidFound,
    required this.tokenFound,
    required this.loginStatus,
    required this.pageStatus,
    required this.sidLength,
    required this.tokenLength,
    required this.message,
  });
}

/// Small, read-only Huawei EG8145V5 session test.
///
/// It does not change router configuration. It only:
/// 1. gets the one-time login token,
/// 2. logs in,
/// 3. captures the authenticated SID cookie,
/// 4. opens newacl.asp and extracts the fresh onttoken.
class HuaweiSessionTest {
  final String baseUrl;
  final http.Client _client;

  HuaweiSessionTest({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> _headers({String? cookie, String? referer}) {
    final headers = <String, String>{
      'Accept': '*/*',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
    };
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    if (referer != null) headers['Referer'] = referer;
    return headers;
  }

  String? _firstCookie(String? setCookie) {
    if (setCookie == null || setCookie.trim().isEmpty) return null;
    final first = setCookie.split(';').first.trim();
    return first.isEmpty ? null : first;
  }

  String? _extractSid(String? cookie) {
    if (cookie == null) return null;
    final match = RegExp(r'(?:^|\s|Cookie=)sid=([^:;\s]+)', caseSensitive: false)
        .firstMatch(cookie);
    return match?.group(1);
  }

  String? _extractOntToken(String body) {
    final patterns = <RegExp>[
      RegExp(
        r'''<input[^>]*id\s*=\s*["']hwonttoken["'][^>]*value\s*=\s*["']([^"']+)["']''',
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
      final token = match?.group(1)?.trim();
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  Future<HuaweiSessionTestResult> run({
    required String username,
    required String password,
  }) async {
    String? cookie;
    String? sid;
    var loginStatus = 0;
    var pageStatus = 0;

    try {
      // Step 1: Huawei's one-time login token.
      final randResponse = await _client.get(
        Uri.parse('$baseUrl/asp/GetRandCount.asp'),
        headers: _headers(),
      );

      if (randResponse.statusCode != 200) {
        return HuaweiSessionTestResult(
          loginSuccess: false,
          sidFound: false,
          tokenFound: false,
          loginStatus: randResponse.statusCode,
          pageStatus: 0,
          sidLength: 0,
          tokenLength: 0,
          message: 'GetRandCount failed: HTTP ${randResponse.statusCode}.',
        );
      }

      final loginToken = randResponse.body.replaceFirst('\uFEFF', '').trim();
      if (loginToken.isEmpty) {
        return const HuaweiSessionTestResult(
          loginSuccess: false,
          sidFound: false,
          tokenFound: false,
          loginStatus: 0,
          pageStatus: 0,
          sidLength: 0,
          tokenLength: 0,
          message: 'Huawei did not return the login token.',
        );
      }

      cookie = _firstCookie(randResponse.headers['set-cookie']);

      // Step 2: Login. Huawei expects the password Base64 encoded in this form.
      final encodedPassword = base64Encode(utf8.encode(password));
      final loginResponse = await _client.post(
        Uri.parse('$baseUrl/login.cgi'),
        headers: {
          ..._headers(
            cookie: cookie,
            referer: '$baseUrl/login.asp',
          ),
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': baseUrl,
        },
        body: {
          'UserName': username,
          'PassWord': encodedPassword,
          'Language': 'english',
          'x.X_HW_Token': loginToken,
        },
      );

      loginStatus = loginResponse.statusCode;

      final loginCookie = _firstCookie(loginResponse.headers['set-cookie']);
      if (loginCookie != null) cookie = loginCookie;

      final loginBody = loginResponse.body;
      final loginSuccess = loginResponse.statusCode == 200 &&
          (loginBody.contains("top.location.replace('/')") ||
              !loginBody.toLowerCase().contains('login'));

      if (!loginSuccess || cookie == null) {
        return HuaweiSessionTestResult(
          loginSuccess: false,
          sidFound: false,
          tokenFound: false,
          loginStatus: loginStatus,
          pageStatus: 0,
          sidLength: 0,
          tokenLength: 0,
          message: loginResponse.statusCode == 200
              ? 'Login response was received, but no authenticated SID was established.'
              : 'Huawei login failed: HTTP ${loginResponse.statusCode}.',
        );
      }

      // Step 3: Extract the session SID without displaying its value.
      sid = _extractSid(cookie);
      if (sid == null || sid.isEmpty) {
        return HuaweiSessionTestResult(
          loginSuccess: true,
          sidFound: false,
          tokenFound: false,
          loginStatus: loginStatus,
          pageStatus: 0,
          sidLength: 0,
          tokenLength: 0,
          message: 'Login succeeded, but SID was not found in the session cookie.',
        );
      }

      // Step 4: Open the exact page used by Device Access Control.
      final pageResponse = await _client.get(
        Uri.parse('$baseUrl/html/bbsp/portacl/newacl.asp'),
        headers: _headers(
          cookie: cookie,
          referer: '$baseUrl/index.asp',
        ),
      );

      pageStatus = pageResponse.statusCode;
      final ontToken = _extractOntToken(pageResponse.body);

      if (pageResponse.statusCode != 200 || ontToken == null) {
        return HuaweiSessionTestResult(
          loginSuccess: true,
          sidFound: true,
          tokenFound: false,
          loginStatus: loginStatus,
          pageStatus: pageStatus,
          sidLength: sid.length,
          tokenLength: 0,
          message: pageResponse.statusCode == 200
              ? 'SID is valid, but onttoken was not found on newacl.asp.'
              : 'SID is valid, but newacl.asp returned HTTP ${pageResponse.statusCode}.',
        );
      }

      return HuaweiSessionTestResult(
        loginSuccess: true,
        sidFound: true,
        tokenFound: true,
        loginStatus: loginStatus,
        pageStatus: pageStatus,
        sidLength: sid.length,
        tokenLength: ontToken.length,
        message: 'Huawei session established successfully.',
      );
    } catch (e) {
      return HuaweiSessionTestResult(
        loginSuccess: false,
        sidFound: sid != null,
        tokenFound: false,
        loginStatus: loginStatus,
        pageStatus: pageStatus,
        sidLength: sid?.length ?? 0,
        tokenLength: 0,
        message: 'Session test error: $e',
      );
    }
  }

  void close() => _client.close();
}
