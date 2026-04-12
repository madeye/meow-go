import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../services/vpn_channel.dart';
import '../services/traffic_history.dart';
import '../models/vpn_state.dart';
import '../models/traffic_stats.dart';

class TrafficScreen extends StatefulWidget {
  const TrafficScreen({super.key});

  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  final _vpn = VpnChannel.instance;
  final _history = TrafficHistory.instance;
  VpnState _state = VpnState.stopped;
  TrafficStats _traffic = const TrafficStats();
  final List<_TrafficSample> _samples = [];
  StreamSubscription? _stateSub;
  StreamSubscription? _trafficSub;
  int _sessionUpload = 0;
  int _sessionDownload = 0;
  int _trafficUpdateCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _history.load();
    if (mounted) setState(() {});
    _loadState();
    _stateSub = _vpn.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      if (s == VpnState.connected) {
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
      // Reload history from DB every 10 updates (~10 seconds)
      _trafficUpdateCount++;
      if (_trafficUpdateCount % 10 == 0) {
        _history.load().then((_) { if (mounted) setState(() {}); });
      }
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
    final todayTraffic = _history.today;
    final monthTraffic = _history.thisMonth;

    return Scaffold(
      appBar: AppBar(title: Text(s.traffic)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Connection status
          _StatusIndicator(connected: isOn),
          const SizedBox(height: 16),

          // Today & This Month
          _SectionTitle(s.dataUsage),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _UsageCard(
                  label: s.today,
                  icon: Icons.today,
                  color: Colors.amber,
                  tx: todayTraffic.tx,
                  rx: todayTraffic.rx,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _UsageCard(
                  label: s.thisMonth,
                  icon: Icons.calendar_month,
                  color: Colors.orange,
                  tx: monthTraffic.tx,
                  rx: monthTraffic.rx,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Daily history chart
          _SectionTitle(s.dailyHistory),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _history.days.isEmpty
                ? Center(
                    child: Text(
                      s.noHistoryData,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : _DailyChart(days: _history.days),
          ),
          const SizedBox(height: 24),

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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : _SpeedChart(samples: _samples),
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
    final theme = Theme.of(context);
    final color = connected
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          connected ? s.connected : s.disconnected,
          style: TextStyle(
            color: color,
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

class _UsageCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int tx;
  final int rx;

  const _UsageCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.tx,
    required this.rx,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _TrafficScreenState._formatBytes(tx + rx),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 4),
            Builder(builder: (context) {
              final muted = Theme.of(context).colorScheme.onSurfaceVariant;
              return Row(
                children: [
                  Icon(Icons.arrow_upward, size: 12, color: Colors.blue.withAlpha(180)),
                  const SizedBox(width: 2),
                  Text(_TrafficScreenState._formatBytes(tx), style: TextStyle(fontSize: 11, color: muted)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_downward, size: 12, color: Colors.green.withAlpha(180)),
                  const SizedBox(width: 2),
                  Text(_TrafficScreenState._formatBytes(rx), style: TextStyle(fontSize: 11, color: muted)),
                ],
              );
            }),
          ],
        ),
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
            Builder(builder: (context) => Text(
              rate,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// --- Daily bar chart (interactive) ---

class _DailyChart extends StatefulWidget {
  final List<DailyTraffic> days;
  const _DailyChart({required this.days});

  @override
  State<_DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<_DailyChart> {
  int? _selectedIndex;
  List<DailyTraffic>? _cachedAllDays;
  List<DailyTraffic>? _lastDays;

  List<DailyTraffic> _getAllDays() {
    if (_cachedAllDays != null && identical(_lastDays, widget.days)) {
      return _cachedAllDays!;
    }
    _lastDays = widget.days;
    final now = DateTime.now();
    final allDays = <DailyTraffic>[];
    for (var i = 29; i >= 0; i--) {
      final dt = now.subtract(Duration(days: i));
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final entry = widget.days.cast<DailyTraffic?>().firstWhere((d) => d!.date == key, orElse: () => null);
      allDays.add(entry ?? DailyTraffic(date: key));
    }
    _cachedAllDays = allDays;
    return allDays;
  }

  @override
  Widget build(BuildContext context) {
    final allDays = _getAllDays();
    final selected = _selectedIndex != null && _selectedIndex! < allDays.length
        ? allDays[_selectedIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tooltip for selected day
        SizedBox(
          height: 36,
          child: selected != null
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        selected.date,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_upward, size: 11, color: Colors.blue.withAlpha(200)),
                      const SizedBox(width: 2),
                      Text(
                        _TrafficScreenState._formatBytes(selected.tx),
                        style: const TextStyle(fontSize: 11, color: Colors.blue, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.arrow_downward, size: 11, color: Colors.green.withAlpha(200)),
                      const SizedBox(width: 2),
                      Text(
                        _TrafficScreenState._formatBytes(selected.rx),
                        style: const TextStyle(fontSize: 11, color: Colors.green, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.swap_vert, size: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text(
                        _TrafficScreenState._formatBytes(selected.total),
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    S.of(context).tapBarHint,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
        // Chart
        Expanded(
          child: GestureDetector(
            onTapDown: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final localX = details.localPosition.dx;
              final leftMargin = 44.0;
              final chartW = box.size.width - leftMargin;
              if (localX < leftMargin) return;
              final index = ((localX - leftMargin) / chartW * 30).floor().clamp(0, 29);
              setState(() {
                _selectedIndex = _selectedIndex == index ? null : index;
              });
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: _DailyChartPainter(
                days: allDays,
                selectedIndex: _selectedIndex,
                uploadLabel: S.of(context).upload,
                downloadLabel: S.of(context).download,
                gridColor: Theme.of(context).colorScheme.outlineVariant,
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyChartPainter extends CustomPainter {
  final List<DailyTraffic> days;
  final int? selectedIndex;
  final String uploadLabel;
  final String downloadLabel;
  final Color gridColor;
  final Color labelColor;
  _DailyChartPainter({
    required this.days,
    this.selectedIndex,
    required this.uploadLabel,
    required this.downloadLabel,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bottomMargin = 28.0;
    final leftMargin = 44.0;
    final chartW = w - leftMargin;
    final chartH = h - bottomMargin;

    // Find max
    int maxTotal = 1;
    for (final d in days) {
      maxTotal = max(maxTotal, d.total);
    }

    // Grid
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = (chartH / 4) * i;
      canvas.drawLine(Offset(leftMargin, y), Offset(w, y), gridPaint);
    }

    // Y-axis labels
    final yLabelStyle = TextStyle(color: labelColor, fontSize: 9, fontFeatures: const [FontFeature.tabularFigures()]);
    for (var i = 0; i <= 4; i++) {
      final val = maxTotal * (4 - i) ~/ 4;
      final y = (chartH / 4) * i;
      _drawText(canvas, _formatBytes(val), Offset(0, y - 6), yLabelStyle, leftMargin - 4);
    }

    // Bars
    final barCount = days.length;
    final barWidth = (chartW / barCount) * 0.7;
    final gap = (chartW / barCount) * 0.3;

    for (var i = 0; i < barCount; i++) {
      final d = days[i];
      final x = leftMargin + (chartW / barCount) * i + gap / 2;
      final isSelected = i == selectedIndex;

      // Download (green) on bottom, Upload (blue) on top
      final rxH = (d.rx / maxTotal) * chartH;
      final txH = (d.tx / maxTotal) * chartH;

      final rxAlpha = isSelected ? 255 : 140;
      final txAlpha = isSelected ? 255 : 140;

      // Highlight background for selected bar
      if (isSelected) {
        final highlightRect = Rect.fromLTWH(
          leftMargin + (chartW / barCount) * i, 0, chartW / barCount, chartH);
        canvas.drawRect(highlightRect, Paint()..color = labelColor.withAlpha(15));
      }

      // Download bar
      if (rxH > 0) {
        final rxRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartH - rxH, barWidth, rxH),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(rxRect, Paint()..color = Colors.green.withAlpha(rxAlpha));
      }

      // Upload bar (stacked on top)
      if (txH > 0) {
        final txRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartH - rxH - txH, barWidth, txH),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(txRect, Paint()..color = Colors.blue.withAlpha(txAlpha));
      }

      // X-axis labels (show every 5 days, last day, and selected)
      if (i % 5 == 0 || i == barCount - 1 || isSelected) {
        final dateLabel = d.date.substring(5); // MM-DD
        _drawText(
          canvas,
          dateLabel,
          Offset(x - 2, chartH + 4),
          TextStyle(color: labelColor, fontSize: 8,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
          40,
        );
      }
    }

    // Legend
    final legendY = h - 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - 80, legendY - 5, 10, 10), const Radius.circular(2)),
      Paint()..color = Colors.blue.withAlpha(180),
    );
    _drawText(canvas, uploadLabel, Offset(w / 2 - 66, legendY - 7), TextStyle(color: labelColor, fontSize: 10), 50);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 + 10, legendY - 5, 10, 10), const Radius.circular(2)),
      Paint()..color = Colors.green.withAlpha(180),
    );
    _drawText(canvas, downloadLabel, Offset(w / 2 + 24, legendY - 7), TextStyle(color: labelColor, fontSize: 10), 60);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)}G';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(0)}M';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)}K';
    return '${bytes}B';
  }

  @override
  bool shouldRepaint(covariant _DailyChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex || oldDelegate.days != days ||
      oldDelegate.gridColor != gridColor || oldDelegate.labelColor != labelColor;
}

// --- Speed chart ---

class _SpeedChart extends StatelessWidget {
  final List<_TrafficSample> samples;
  const _SpeedChart({required this.samples});

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox();

    int maxRate = 1024;
    for (final s in samples) {
      maxRate = max(maxRate, max(s.txRate, s.rxRate));
    }

    final s = S.of(context);
    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: _ChartPainter(
        samples: samples,
        maxRate: maxRate,
        uploadLabel: s.upload,
        downloadLabel: s.download,
        gridColor: Theme.of(context).colorScheme.outlineVariant,
        labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<_TrafficSample> samples;
  final int maxRate;
  final String uploadLabel;
  final String downloadLabel;
  final Color gridColor;
  final Color labelColor;

  _ChartPainter({
    required this.samples,
    required this.maxRate,
    required this.uploadLabel,
    required this.downloadLabel,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    final w = size.width;
    final h = size.height;
    final margin = 40.0;
    final chartW = w - margin;
    final chartH = h - 24;

    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = (chartH / 4) * i;
      canvas.drawLine(Offset(margin, y), Offset(w, y), gridPaint);
    }

    final yLabelStyle = TextStyle(color: labelColor, fontSize: 10, fontFeatures: const [FontFeature.tabularFigures()]);
    for (var i = 0; i <= 4; i++) {
      final val = maxRate * (4 - i) / 4;
      final y = (chartH / 4) * i;
      _drawText(canvas, _formatRate(val.toInt()), Offset(0, y - 6), yLabelStyle, margin - 4);
    }

    _drawLine(canvas, samples.map((s) => s.txRate).toList(), Colors.blue, margin, chartW, chartH);
    _drawLine(canvas, samples.map((s) => s.rxRate).toList(), Colors.green, margin, chartW, chartH);
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
    canvas.drawCircle(Offset(size.width / 2 - 60, y), 4, Paint()..color = Colors.blue);
    _drawText(canvas, uploadLabel, Offset(size.width / 2 - 52, y - 6),
        TextStyle(color: labelColor, fontSize: 10), 50);
    canvas.drawCircle(Offset(size.width / 2 + 20, y), 4, Paint()..color = Colors.green);
    _drawText(canvas, downloadLabel, Offset(size.width / 2 + 28, y - 6),
        TextStyle(color: labelColor, fontSize: 10), 60);
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
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.samples.length != samples.length ||
      oldDelegate.maxRate != maxRate ||
      (samples.isNotEmpty && oldDelegate.samples.last.time != samples.last.time) ||
      oldDelegate.gridColor != gridColor || oldDelegate.labelColor != labelColor;
}
