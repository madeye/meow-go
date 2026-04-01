import 'vpn_channel.dart';

class DailyTraffic {
  final String date; // yyyy-MM-dd
  final int tx;
  final int rx;

  const DailyTraffic({required this.date, this.tx = 0, this.rx = 0});

  int get total => tx + rx;

  factory DailyTraffic.fromMap(Map<String, dynamic> map) => DailyTraffic(
        date: map['date'] as String? ?? '',
        tx: (map['tx'] as num?)?.toInt() ?? 0,
        rx: (map['rx'] as num?)?.toInt() ?? 0,
      );
}

class TrafficHistory {
  static TrafficHistory? _instance;
  static TrafficHistory get instance => _instance ??= TrafficHistory._();
  TrafficHistory._();

  List<DailyTraffic> _days = [];

  List<DailyTraffic> get days => List.unmodifiable(_days);

  /// Get today's traffic record.
  DailyTraffic get today {
    final now = DateTime.now();
    final key = _dateKey(now);
    for (final d in _days) {
      if (d.date == key) return d;
    }
    return DailyTraffic(date: key);
  }

  /// Get this month's total traffic.
  DailyTraffic get thisMonth {
    final now = DateTime.now();
    final prefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    int tx = 0, rx = 0;
    for (final d in _days) {
      if (d.date.startsWith(prefix)) {
        tx += d.tx;
        rx += d.rx;
      }
    }
    return DailyTraffic(date: prefix, tx: tx, rx: rx);
  }

  /// Load history from Room database via platform channel.
  Future<void> load() async {
    final list = await VpnChannel.instance.getTrafficHistory();
    _days = list.map((e) => DailyTraffic.fromMap(e)).toList();
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
