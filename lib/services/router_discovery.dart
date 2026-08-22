import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;

class RouterDiscovery {
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<String?> detectGateway() async {
    try {
      final gateway = await _networkInfo.getWifiGatewayIP();
      return gateway;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getWifiIp() async {
    try {
      return await _networkInfo.getWifiIP();
    } catch (_) {
      return null;
    }
  }

  Future<bool> testRouter(String ip) async {
    final cleanIp = ip.trim();

    if (cleanIp.isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse('http://$cleanIp/api');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 3));

      // A router may return 400 for a GET /api request.
      // That still proves the HTTP server is reachable.
      return response.statusCode >= 200 &&
          response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}