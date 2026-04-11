import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/strings.dart';
import '../models/log_entry.dart';
import '../services/mihomo_api.dart';

class LogsScreen extends StatefulWidget {
  /// Overrides the log stream factory. Pass a custom factory in tests to
  /// avoid depending on [MihomoApi.instance] (which requires the embedded
  /// on-device engine). In production, leave null — the real engine stream
  /// is used automatically.
  final Stream<LogEntry> Function({String level})? streamLogsOverride;

  const LogsScreen({super.key, this.streamLogsOverride});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  static const _kMaxEntries = 1000;
  static const _levelOptions = ['debug', 'info', 'warning', 'error', 'silent'];

  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<LogEntry>? _subscription;
  bool _paused = false;
  bool _autoScroll = true;
  String _level = 'info';

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribe() {
    _subscription?.cancel();
    final stream = widget.streamLogsOverride?.call(level: _level) ??
        MihomoApi.instance.streamLogs(level: _level);
    _subscription = stream.listen(
      (entry) {
        if (!mounted || _paused) return;
        setState(() {
          _logs.add(entry);
          if (_logs.length > _kMaxEntries) {
            _logs.removeRange(0, _logs.length - _kMaxEntries);
          }
        });
        if (_autoScroll && _scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController
                  .jumpTo(_scrollController.position.maxScrollExtent);
            }
          });
        }
      },
      onError: (_) {}, // MihomoApi handles reconnection automatically
    );
  }

  void _togglePause() => setState(() => _paused = !_paused);

  void _clear() => setState(() => _logs.clear());

  void _copyAll() {
    if (_logs.isEmpty) return;
    Clipboard.setData(ClipboardData(
      text: _logs
          .map((e) => '[${e.type}] ${e.time} ${e.payload}')
          .join('\n'),
    ));
  }

  void _onLevelChanged(String? level) {
    if (level == null || level == _level) return;
    setState(() {
      _level = level;
      _logs.clear();
    });
    _subscribe();
  }

  static Color _levelColor(String type) {
    switch (type.toUpperCase()) {
      case 'ERROR':
        return Colors.redAccent;
      case 'WARNING':
      case 'WARN':
        return Colors.orangeAccent;
      case 'DEBUG':
        return Colors.blueAccent;
      case 'INFO':
        return Colors.white60;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.logs),
        actions: [
          // Level filter
          DropdownButton<String>(
            value: _level,
            underline: const SizedBox.shrink(),
            items: _levelOptions
                .map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(
                        l[0].toUpperCase() + l.substring(1),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ))
                .toList(),
            onChanged: _onLevelChanged,
          ),
          const SizedBox(width: 4),
          // Pause / Resume
          IconButton(
            tooltip: _paused ? s.logResume : s.logPause,
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            onPressed: _togglePause,
          ),
          // Copy all
          IconButton(
            tooltip: s.copyAll,
            icon: const Icon(Icons.copy),
            onPressed: _copyAll,
          ),
          // Auto-scroll toggle
          IconButton(
            tooltip: s.autoScroll,
            icon: Icon(_autoScroll
                ? Icons.vertical_align_bottom
                : Icons.vertical_align_center),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          // Clear
          IconButton(
            tooltip: s.clear,
            icon: const Icon(Icons.delete_outline),
            onPressed: _clear,
          ),
        ],
      ),
      body: _logs.isEmpty
          ? Center(
              child: Text(
                s.noLogs,
                style: const TextStyle(color: Colors.white38),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _logs.length,
              semanticChildCount: _logs.length,
              itemBuilder: (_, i) => _buildRow(_logs[i]),
            ),
    );
  }

  Widget _buildRow(LogEntry entry) {
    final color = _levelColor(entry.type);
    final badge =
        entry.type.length > 4 ? entry.type.substring(0, 4) : entry.type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (entry.time.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              entry.time,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white30,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.payload,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
