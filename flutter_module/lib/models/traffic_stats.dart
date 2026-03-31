class TrafficStats {
  final int txRate;
  final int rxRate;
  final int txTotal;
  final int rxTotal;

  const TrafficStats({
    this.txRate = 0,
    this.rxRate = 0,
    this.txTotal = 0,
    this.rxTotal = 0,
  });

  factory TrafficStats.fromMap(Map<dynamic, dynamic> map) => TrafficStats(
        txRate: map['txRate'] as int? ?? 0,
        rxRate: map['rxRate'] as int? ?? 0,
        txTotal: map['txTotal'] as int? ?? 0,
        rxTotal: map['rxTotal'] as int? ?? 0,
      );

  String get txRateStr => _formatRate(txRate);
  String get rxRateStr => _formatRate(rxRate);
  String get txTotalStr => _formatBytes(txTotal);
  String get rxTotalStr => _formatBytes(rxTotal);

  static String _formatRate(int bytesPerSec) => '${_formatBytes(bytesPerSec)}/s';

  static String _formatBytes(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
