import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../services/vpn_channel.dart';
import '../models/vpn_state.dart';
import '../models/traffic_stats.dart';

class TrafficScreen extends StatefulWidget {
  const TrafficScreen({super.key});

  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  final _vpn = VpnChannel.instance;
  VpnState _state = VpnState.stopped;
  TrafficStats _traffic = const TrafficStats();
  final List<_TrafficSample> _samples = [];
  StreamSubscription? _stateSub;
  StreamSubscription? _trafficSub;
  int _sessionUpload = 0;
  int _sessionDownload = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
    _stateSub = _vpn.stateStream.listen((s) {
      if (!mounted) return;
      final wasConnected = _state == VpnState.connected;
      setState(() => _state = s);
      if (s == VpnState.connected && !wasConnected) {
        _sessionUpload = 0;
        _sessionDownload = 0;
        _samples.clear();
      }
    });
    _trafficSub = _vpn.trafficStream.listen((t) {
      if (!mounted) return;
      setState(() {
        _traffic = t;
        _sessionUpload = t.txTotal;
        _sessionDownload = t.rxTotal;
        _samples.add(_TrafficSample(
          time: DateTime.now(),
          txRate: t.txRate,
          rxRate: t.rxRate,
        ));
        if (_samples.length > 60) _samples.removeAt(0);
      });
    });
  }

  Future<void> _loadState() async {
    try {
      final state = await _vpn.getState();
      if (mounted) setState(() => _state = state);
    } catch (_) {}
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _trafficSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isOn = _state == VpnState.connected;

    return Scaffold(
      appBar: AppBar(title: Text(s.traffic)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Connection status
          _StatusIndicator(connected: isOn),
          const SizedBox(height: 16),

          // Current session
          _SectionTitle(s.currentSession),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.arrow_upward,
                  color: Colors.blue,
                  label: s.upload,
                  value: _formatBytes(_sessionUpload),
                  rate: _traffic.txRateStr,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  icon: Icons.arrow_downward,
                  color: Colors.green,
                  label: s.download,
                  value: _formatBytes(_sessionDownload),
                  rate: _traffic.rxRateStr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StatCard(
            icon: Icons.swap_vert,
            color: Colors.purple,
            label: s.total,
            value: _formatBytes(_sessionUpload + _sessionDownload),
            rate: '${_formatBytes(_traffic.txRate + _traffic.rxRate)}/s',
          ),
          const SizedBox(height: 24),

          // Speed chart
          _SectionTitle(s.speedChart),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _samples.length < 2
                ? Center(
                    child: Text(
                      isOn ? s.collectingData : s.connectToSeeTraffic,
                      style: const TextStyle(color: Colors.white38),
                    ),
                  )
                : _SpeedChart(samples: _samples),
          ),
          const SizedBox(height: 24),

          // Session summary
          _SectionTitle(s.sessionSummary),
          const SizedBox(height: 8),
          _SummaryRow(
            label: s.upload,
            icon: Icons.arrow_upward,
            color: Colors.blue,
            bytes: _sessionUpload,
          ),
          _SummaryRow(
            label: s.download,
            icon: Icons.arrow_downward,
            color: Colors.green,
            bytes: _sessionDownload,
          ),
          _SummaryRow(
            label: s.total,
            icon: Icons.swap_vert,
            color: Colors.purple,
            bytes: _sessionUpload + _sessionDownload,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(2)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

class _TrafficSample {
  final DateTime time;
  final int txRate;
  final int rxRate;
  const _TrafficSample({required this.time, required this.txRate, required this.rxRate});
}

// --- Widgets ---

class _StatusIndicator extends StatelessWidget {
  final bool connected;
  const _StatusIndicator({required this.connected});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected ? Colors.greenAccent : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          connected ? s.connected : s.disconnected,
          style: TextStyle(
            color: connected ? Colors.greenAccent : Colors.grey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String rate;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.rate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
            Text(
              rate,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int bytes;

  const _SummaryRow({required this.label, required this.icon, required this.color, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(
            _TrafficScreenState._formatBytes(bytes),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedChart extends StatelessWidget {
  final List<_TrafficSample> samples;
  const _SpeedChart({required this.samples});

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox();

    int maxRate = 1024; // minimum 1 KB/s scale
    for (final s in samples) {
      maxRate = max(maxRate, max(s.txRate, s.rxRate));
    }

    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: _ChartPainter(samples: samples, maxRate: maxRate),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_TrafficSample> samples;
  final int maxRate;

  _ChartPainter({required this.samples, required this.maxRate});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    final w = size.width;
    final h = size.height;
    final margin = 40.0;
    final chartW = w - margin;
    final chartH = h - 24;

    // Background grid
    final gridPaint = Paint()..color = Colors.white10..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = (chartH / 4) * i;
      canvas.drawLine(Offset(margin, y), Offset(w, y), gridPaint);
    }

    // Y-axis labels
    final labelStyle = TextStyle(color: Colors.white38, fontSize: 10, fontFeatures: const [FontFeature.tabularFigures()]);
    for (var i = 0; i <= 4; i++) {
      final val = maxRate * (4 - i) / 4;
      final y = (chartH / 4) * i;
      _drawText(canvas, _formatRate(val.toInt()), Offset(0, y - 6), labelStyle, margin - 4);
    }

    // Upload line (blue)
    _drawLine(canvas, samples.map((s) => s.txRate).toList(), Colors.blue, margin, chartW, chartH);
    // Download line (green)
    _drawLine(canvas, samples.map((s) => s.rxRate).toList(), Colors.green, margin, chartW, chartH);

    // Legend
    _drawLegend(canvas, size);
  }

  void _drawLine(Canvas canvas, List<int> values, Color color, double margin, double chartW, double chartH) {
    if (values.length < 2) return;

    final fillPaint = Paint()
      ..color = color.withAlpha(30)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = margin + (chartW / (values.length - 1)) * i;
      final y = chartH - (values[i] / maxRate) * chartH;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartH);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(margin + chartW, chartH);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  void _drawLegend(Canvas canvas, Size size) {
    final y = size.height - 10;
    final uploadPaint = Paint()..color = Colors.blue;
    final downloadPaint = Paint()..color = Colors.green;

    canvas.drawCircle(Offset(size.width / 2 - 60, y), 4, uploadPaint);
    _drawText(canvas, 'Upload', Offset(size.width / 2 - 52, y - 6),
        const TextStyle(color: Colors.white54, fontSize: 10), 50);

    canvas.drawCircle(Offset(size.width / 2 + 20, y), 4, downloadPaint);
    _drawText(canvas, 'Download', Offset(size.width / 2 + 28, y - 6),
        const TextStyle(color: Colors.white54, fontSize: 10), 60);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  static String _formatRate(int bytesPerSec) {
    if (bytesPerSec >= 1048576) return '${(bytesPerSec / 1048576).toStringAsFixed(1)}M';
    if (bytesPerSec >= 1024) return '${(bytesPerSec / 1024).toStringAsFixed(0)}K';
    return '${bytesPerSec}B';
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
