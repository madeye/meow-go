class RuntimeConfig {
  final String mode;         // rule | global | direct
  final bool ipv6;
  final bool allowLan;
  final String logLevel;
  final int mixedPort;
  final String externalController;

  const RuntimeConfig({
    required this.mode,
    required this.ipv6,
    required this.allowLan,
    required this.logLevel,
    required this.mixedPort,
    required this.externalController,
  });

  factory RuntimeConfig.fromJson(Map<String, dynamic> json) => RuntimeConfig(
        mode: json['mode'] as String? ?? 'rule',
        ipv6: json['ipv6'] as bool? ?? false,
        allowLan: json['allow-lan'] as bool? ?? false,
        logLevel: json['log-level'] as String? ?? 'info',
        mixedPort: json['mixed-port'] as int? ?? 7890,
        externalController: json['external-controller'] as String? ?? '',
      );
}

class MemoryInfo {
  final int inuse;
  final int oslimit;

  const MemoryInfo({required this.inuse, required this.oslimit});

  factory MemoryInfo.fromJson(Map<String, dynamic> json) => MemoryInfo(
        inuse: json['inuse'] as int? ?? 0,
        oslimit: json['oslimit'] as int? ?? 0,
      );
}

class DnsAnswer {
  final int ttl;
  final String data;
  final String name;
  final int type;

  const DnsAnswer({
    required this.ttl,
    required this.data,
    required this.name,
    required this.type,
  });

  factory DnsAnswer.fromJson(Map<String, dynamic> json) => DnsAnswer(
        ttl: json['TTL'] as int? ?? 0,
        data: json['data'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: json['type'] as int? ?? 0,
      );
}

class DnsQueryResult {
  final List<DnsAnswer> answers;
  final int status;

  const DnsQueryResult({required this.answers, required this.status});

  factory DnsQueryResult.fromJson(Map<String, dynamic> json) => DnsQueryResult(
        answers: (json['Answer'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DnsAnswer.fromJson)
            .toList(),
        status: json['Status'] as int? ?? 0,
      );
}
