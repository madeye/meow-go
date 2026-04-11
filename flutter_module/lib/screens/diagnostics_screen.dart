import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/strings.dart';
import '../services/mihomo_api.dart';

typedef DiagFn = Future<String> Function();

const _kVpnChannel = MethodChannel('io.github.madeye.meow/vpn');

class DiagnosticsScreen extends StatelessWidget {
  final DiagFn? directTcpOverride;
  final DiagFn? proxyHttpOverride;
  final DiagFn? dnsResolverOverride;
  final DiagFn? dnsQueryOverride;

  const DiagnosticsScreen({
    super.key,
    this.directTcpOverride,
    this.proxyHttpOverride,
    this.dnsResolverOverride,
    this.dnsQueryOverride,
  });

  static Future<String> _defaultDirectTcp() async {
    final r = await _kVpnChannel.invokeMethod<String>('testDirectTcp', {
      'host': '1.1.1.1',
      'port': 80,
    });
    return r ?? 'FAIL (no response)';
  }

  static Future<String> _defaultProxyHttp() async {
    final r = await _kVpnChannel.invokeMethod<String>('testProxyHttp', {
      'url': 'http://www.gstatic.com/generate_204',
    });
    return r ?? 'FAIL (no response)';
  }

  static Future<String> _defaultDnsResolver() async {
    final r = await _kVpnChannel.invokeMethod<String>('testDnsResolver', {
      'addr': '127.0.0.1:1053',
    });
    return r ?? 'FAIL (no response)';
  }

  static Future<String> _defaultDnsQuery() async {
    try {
      final result = await MihomoApi.instance.dnsQuery('example.com');
      if (result.answers.isNotEmpty) {
        return 'OK: ${result.answers.map((a) => a.data).join(', ')}';
      }
      return 'FAIL (status=${result.status})';
    } catch (e) {
      return 'FAIL $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.diagnostics)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _DiagTile(
            title: s.diagDirectTcp,
            description: s.diagDirectTcpDesc,
            run: directTcpOverride ?? _defaultDirectTcp,
          ),
          _DiagTile(
            title: s.diagProxyHttp,
            description: s.diagProxyHttpDesc,
            run: proxyHttpOverride ?? _defaultProxyHttp,
          ),
          _DiagTile(
            title: s.diagDnsResolver,
            description: s.diagDnsResolverDesc,
            run: dnsResolverOverride ?? _defaultDnsResolver,
          ),
          _DiagTile(
            title: s.diagDnsQuery,
            description: s.diagDnsQueryDesc,
            run: dnsQueryOverride ?? _defaultDnsQuery,
          ),
        ],
      ),
    );
  }
}

class _DiagTile extends StatefulWidget {
  final String title;
  final String description;
  final DiagFn run;

  const _DiagTile({
    required this.title,
    required this.description,
    required this.run,
  });

  @override
  State<_DiagTile> createState() => _DiagTileState();
}

class _DiagTileState extends State<_DiagTile> {
  String? _result;
  bool _running = false;

  Future<void> _onRun() async {
    if (_running) return;
    setState(() {
      _running = true;
      _result = null;
    });
    try {
      final r = await widget.run();
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _result = 'FAIL $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final resultColor = _result == null
        ? Colors.white38
        : _result!.startsWith('OK')
        ? Colors.greenAccent
        : Colors.redAccent;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _running ? null : _onRun,
                  child: Text(_running ? s.diagRunning : s.diagRun),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _result ?? s.diagNotRun,
              style: TextStyle(fontSize: 12, color: resultColor),
            ),
          ],
        ),
      ),
    );
  }
}
