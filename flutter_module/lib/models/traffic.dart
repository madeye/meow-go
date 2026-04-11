/// Traffic data from the mihomo external-controller WebSocket stream (/traffic).
/// Distinct from [TrafficStats] which comes from the Kotlin EventChannel.
class MihomoTraffic {
  final int up;    // bytes per second upload
  final int down;  // bytes per second download

  const MihomoTraffic({required this.up, required this.down});

  factory MihomoTraffic.fromJson(Map<String, dynamic> json) => MihomoTraffic(
        up: json['up'] as int? ?? 0,
        down: json['down'] as int? ?? 0,
      );
}
