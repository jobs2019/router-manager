import 'huawei_api.dart';

extension HuaweiWifiPassword on HuaweiApi {
  Future<String> get2GCurrentPassword() async {
    final pages = <String>[
      '/html/amp/wlanbasic/WlanBasic.asp?2G',
      '/html/amp/wlanbasic/simplewificfg.asp',
    ];

    for (final path in pages) {
      final body = await getPage(path);

      final names = <String>[
        'k.PreSharedKey',
        'psk1.PreSharedKey',
        'm.Key',
      ];

      for (final name in names) {
        final escaped = RegExp.escape(name);
        final patterns = <RegExp>[
          RegExp(
            '<input[^>]+name=["\']$escaped["\'][^>]+value=["\']([^"\']*)["\']',
            caseSensitive: false,
          ),
          RegExp(
            '<input[^>]+value=["\']([^"\']*)["\'][^>]+name=["\']$escaped["\']',
            caseSensitive: false,
          ),
        ];

        for (final pattern in patterns) {
          final match = pattern.firstMatch(body);
          if (match != null) {
            final value = match.group(1)?.trim() ?? '';
            if (value.isNotEmpty && !_isMasked(value)) {
              return _decodeHtml(value);
            }
          }
        }
      }
    }

    return '';
  }

  bool _isMasked(String value) {
    if (value.isEmpty) return true;
    return value.replaceAll('*', '').replaceAll('•', '').isEmpty;
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
