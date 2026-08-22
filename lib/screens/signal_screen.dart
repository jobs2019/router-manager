import 'dart:async';

import 'package:flutter/material.dart';

import '../services/se06_api.dart';

class SignalScreen extends StatefulWidget {
  final Se06Api api;

  const SignalScreen({
    super.key,
    required this.api,
  });

  @override
  State<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends State<SignalScreen> {
  Timer? _refreshTimer;

  bool _loading = true;
  bool _refreshing = false;

  String? _error;

  String _network = 'Unknown';

  String _lteBand = 'Unknown';
  String _nrBand = 'Unknown';

  String _rsrp = 'Unknown';
  String _rsrq = 'Unknown';
  String _rssi = 'Unknown';
  String _sinr = 'Unknown';

  String _nrRsrp = 'Unknown';
  String _nrRsrq = 'Unknown';
  String _nrSinr = 'Unknown';

  String _cell = 'Unknown';
  String _pci = 'Unknown';
  String _earfcn = 'Unknown';
  String _nrArfcn = 'Unknown';

  String _ipAddress = 'Unknown';
  String _dns1 = 'Unknown';
  String _dns2 = 'Unknown';

  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();

    _loadSignal(
      showLoading: true,
    );

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        _loadSignal(
          showLoading: false,
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    super.dispose();
  }

  Future<void> _loadSignal({
    required bool showLoading,
  }) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final data = await widget.api.dashboard();

      final result = data['result'];

      if (result is! Map) {
        throw Exception(
          'Invalid dashboard response from router.',
        );
      }

      _parseSignal(result);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = null;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
        _error = e.toString();
      });
    }
  }

  void _parseSignal(Map result) {
    final lte = result['lte'];

    if (lte is! Map) {
      throw Exception(
        'Router did not return mobile network information.',
      );
    }

    final status = lte['status'];
    final info = lte['info'];

    String network = 'Unknown';

    String ip = 'Unknown';
    String dns1 = 'Unknown';
    String dns2 = 'Unknown';

    String lteBand = 'Unknown';
    String nrBand = 'Unknown';

    String rsrp = 'Unknown';
    String rsrq = 'Unknown';
    String rssi = 'Unknown';
    String sinr = 'Unknown';

    String nrRsrp = 'Unknown';
    String nrRsrq = 'Unknown';
    String nrSinr = 'Unknown';

    String cell = 'Unknown';
    String pci = 'Unknown';
    String earfcn = 'Unknown';
    String nrArfcn = 'Unknown';

    if (status is Map) {
      final ipv4 = status['ipv4addr'];
      final d1 = status['ipv4dns1'];
      final d2 = status['ipv4dns2'];

      if (ipv4 != null) {
        ip = ipv4.toString();
      }

      if (d1 != null) {
        dns1 = d1.toString();
      }

      if (d2 != null) {
        dns2 = d2.toString();
      }
    }

    if (info is Map) {
      final lte4g = info['LTE_4G'];
      final lte5g = info['LTE_5G'];
      final lteNsa = info['LTE_NSA'];

      if (lteNsa == 1 ||
          lte5g == 1 ||
          lte5g == 2) {
        network = '5G NSA';
      } else if (lte4g == 1) {
        network = '4G LTE';
      }

      final qeng = info['LTE_CELL'];

      if (qeng != null) {
        final parsed = _parseQeng(
          qeng.toString(),
        );

        lteBand =
            parsed['lteBand'] ?? lteBand;

        nrBand =
            parsed['nrBand'] ?? nrBand;

        rsrp =
            parsed['rsrp'] ?? rsrp;

        rsrq =
            parsed['rsrq'] ?? rsrq;

        rssi =
            parsed['rssi'] ?? rssi;

        sinr =
            parsed['sinr'] ?? sinr;

        nrRsrp =
            parsed['nrRsrp'] ?? nrRsrp;

        nrRsrq =
            parsed['nrRsrq'] ?? nrRsrq;

        nrSinr =
            parsed['nrSinr'] ?? nrSinr;

        cell =
            parsed['cell'] ?? cell;

        pci =
            parsed['pci'] ?? pci;

        earfcn =
            parsed['earfcn'] ?? earfcn;

        nrArfcn =
            parsed['nrArfcn'] ?? nrArfcn;
      }
    }

    if (!mounted) return;

    setState(() {
      _network = network;

      _lteBand = lteBand;
      _nrBand = nrBand;

      _rsrp = rsrp;
      _rsrq = rsrq;
      _rssi = rssi;
      _sinr = sinr;

      _nrRsrp = nrRsrp;
      _nrRsrq = nrRsrq;
      _nrSinr = nrSinr;

      _cell = cell;
      _pci = pci;

      _earfcn = earfcn;
      _nrArfcn = nrArfcn;

      _ipAddress = ip;
      _dns1 = dns1;
      _dns2 = dns2;
    });
  }

  Map<String, String> _parseQeng(
    String raw,
  ) {
    final result = <String, String>{};

    final lines = raw.split('\n');

    for (final originalLine in lines) {
      final line = originalLine.trim();

      if (line.startsWith('+QENG: "LTE"')) {
        final values = _extractQengValues(line);

        /*
         * SE06 LTE QENG response:
         *
         * +QENG: "LTE","FDD",
         * MCC,
         * MNC,
         * Cell ID,
         * PCI,
         * EARFCN,
         * Band,
         * ...
         * RSRP,
         * RSRQ,
         * RSSI,
         * SINR,
         * ...
         */

        if (values.length >= 15) {
          result['cell'] = values[4];

          result['pci'] = values[5];

          result['earfcn'] = values[6];

          result['lteBand'] =
              'B${values[7]}';

          result['rsrp'] =
              '${values[11]} dBm';

          result['rsrq'] =
              '${values[12]} dB';

          result['rssi'] =
              '${values[13]} dBm';

          result['sinr'] =
              '${values[14]} dB';
        }
      }

      if (line.startsWith(
        '+QENG: "NR5G-NSA"',
      )) {
        final values =
            _extractQengValues(line);

        /*
         * SE06 NR5G-NSA response:
         *
         * 0 = NR5G-NSA
         * 1 = MCC
         * 2 = MNC
         * 3 = PCI
         * 4 = RSRP
         * 5 = SINR
         * 6 = RSRQ
         * 7 = NR-ARFCN
         * 8 = Band
         */

        if (values.length >= 9) {
          result['nrBand'] =
              'n${values[8]}';

          result['nrRsrp'] =
              '${values[4]} dBm';

          result['nrSinr'] =
              '${values[5]} dB';

          result['nrRsrq'] =
              '${values[6]} dB';

          result['nrArfcn'] =
              values[7];
        }
      }
    }

    return result;
  }

  List<String> _extractQengValues(
    String line,
  ) {
    final colonIndex =
        line.indexOf(':');

    if (colonIndex == -1) {
      return [];
    }

    final content = line.substring(
      colonIndex + 1,
    );

    return content
        .split(',')
        .map(
          (value) => value
              .trim()
              .replaceAll('"', ''),
        )
        .toList();
  }

  String _signalQuality(
    String value,
  ) {
    final number = double.tryParse(
      value.replaceAll(
        RegExp(r'[^0-9\-.]'),
        '',
      ),
    );

    if (number == null) {
      return 'Unknown';
    }

    if (number >= -80) {
      return 'Excellent';
    }

    if (number >= -90) {
      return 'Good';
    }

    if (number >= -100) {
      return 'Fair';
    }

    return 'Poor';
  }

  Widget _buildSignalIndicator() {
    /*
     * For 5G NSA, use the actual 5G NR RSRP
     * as the primary signal-quality indicator.
     *
     * If NR data is unavailable, fall back to LTE RSRP.
     */

    final primaryRsrp =
        _nrRsrp != 'Unknown'
            ? _nrRsrp
            : _rsrp;

    final quality =
        _signalQuality(primaryRsrp);

    IconData icon;

    if (quality == 'Excellent') {
      icon =
          Icons.signal_cellular_4_bar;
    } else if (quality == 'Good') {
      icon =
          Icons.network_cell;
    } else if (quality == 'Fair') {
      icon =
          Icons.network_cell;
    } else if (quality == 'Poor') {
      icon =
          Icons.signal_cellular_0_bar;
    } else {
      icon =
          Icons.signal_cellular_null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              icon,
              size: 48,
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Signal Quality',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    quality,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    primaryRsrp,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
            ),
          ),

          const SizedBox(width: 20),

          Flexible(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Reading 5G signal information...',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () {
        return _loadSignal(
          showLoading: false,
        );
      },
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _network,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _nrBand == 'Unknown'
                          ? 'Mobile Network'
                          : '5G NSA • $_nrBand',
                      style:
                          const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              if (_refreshing)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          if (_lastUpdated != null)
            Text(
              'Last updated ${_formatLastUpdated()}',
              style: const TextStyle(
                fontSize: 12,
              ),
            ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              'Refresh failed. Showing previous data.',
              style: TextStyle(
                fontSize: 12,
                color:
                    Theme.of(context)
                        .colorScheme
                        .error,
              ),
            ),
          ],

          const SizedBox(height: 20),

          _buildSignalIndicator(),

          const SizedBox(height: 16),

          _buildInfoCard(
            title: '5G NR Signal',
            children: [
              _buildRow(
                'Band',
                _nrBand,
              ),
              _buildRow(
                'RSRP',
                _nrRsrp,
              ),
              _buildRow(
                'RSRQ',
                _nrRsrq,
              ),
              _buildRow(
                'SINR',
                _nrSinr,
              ),
              _buildRow(
                'NR-ARFCN',
                _nrArfcn,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoCard(
            title: 'LTE Anchor',
            children: [
              _buildRow(
                'Band',
                _lteBand,
              ),
              _buildRow(
                'RSRP',
                _rsrp,
              ),
              _buildRow(
                'RSRQ',
                _rsrq,
              ),
              _buildRow(
                'RSSI',
                _rssi,
              ),
              _buildRow(
                'SINR',
                _sinr,
              ),
              _buildRow(
                'EARFCN',
                _earfcn,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoCard(
            title: 'Cell Information',
            children: [
              _buildRow(
                'Cell ID',
                _cell,
              ),
              _buildRow(
                'PCI',
                _pci,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoCard(
            title: 'Mobile Connection',
            children: [
              _buildRow(
                'IP Address',
                _ipAddress,
              ),
              _buildRow(
                'DNS 1',
                _dns1,
              ),
              _buildRow(
                'DNS 2',
                _dns2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLastUpdated() {
    final time = _lastUpdated;

    if (time == null) {
      return '';
    }

    final hour =
        time.hour.toString().padLeft(2, '0');

    final minute =
        time.minute.toString().padLeft(2, '0');

    final second =
        time.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '5G Signal',
        ),
        actions: [
          IconButton(
            onPressed: _refreshing
                ? null
                : () {
                    _loadSignal(
                      showLoading: false,
                    );
                  },
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _buildContent(),
    );
  }
}