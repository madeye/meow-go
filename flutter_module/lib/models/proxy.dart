class ProxyHistory {
  final String time;
  final int delay; // ms; 0 = timeout/untested

  const ProxyHistory({required this.time, required this.delay});

  factory ProxyHistory.fromJson(Map<String, dynamic> json) => ProxyHistory(
        time: json['time'] as String? ?? '',
        delay: json['delay'] as int? ?? 0,
      );
}

class Proxy {
  final String name;
  final String type;
  final List<ProxyHistory> history;

  const Proxy({
    required this.name,
    required this.type,
    required this.history,
  });

  factory Proxy.fromJson(String name, Map<String, dynamic> json) => Proxy(
        name: name,
        type: json['type'] as String? ?? '',
        history: (json['history'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ProxyHistory.fromJson)
            .toList(),
      );

  /// Delay from the most recent history entry; 0 if none.
  int get latestDelay => history.isNotEmpty ? history.last.delay : 0;
}
