class ConnectionMeta {
  final String network;
  final String type;
  final String sourceIP;
  final String destinationIP;
  final String sourcePort;
  final String destinationPort;
  final String host;
  final String dnsMode;
  final String processName;
  final int uid;

  const ConnectionMeta({
    required this.network,
    required this.type,
    required this.sourceIP,
    required this.destinationIP,
    required this.sourcePort,
    required this.destinationPort,
    required this.host,
    required this.dnsMode,
    required this.processName,
    required this.uid,
  });

  factory ConnectionMeta.fromJson(Map<String, dynamic> json) => ConnectionMeta(
        network: json['network'] as String? ?? '',
        type: json['type'] as String? ?? '',
        sourceIP: json['sourceIP'] as String? ?? '',
        destinationIP: json['destinationIP'] as String? ?? '',
        sourcePort: json['sourcePort'] as String? ?? '',
        destinationPort: json['destinationPort'] as String? ?? '',
        host: json['host'] as String? ?? '',
        dnsMode: json['dnsMode'] as String? ?? '',
        processName: json['processName'] as String? ?? '',
        uid: json['uid'] as int? ?? 0,
      );
}

class Connection {
  final String id;
  final ConnectionMeta metadata;
  final int upload;
  final int download;
  final String start;
  final List<String> chains;
  final String rule;
  final String rulePayload;

  const Connection({
    required this.id,
    required this.metadata,
    required this.upload,
    required this.download,
    required this.start,
    required this.chains,
    required this.rule,
    required this.rulePayload,
  });

  factory Connection.fromJson(Map<String, dynamic> json) => Connection(
        id: json['id'] as String? ?? '',
        metadata: ConnectionMeta.fromJson(
          json['metadata'] as Map<String, dynamic>? ?? {},
        ),
        upload: json['upload'] as int? ?? 0,
        download: json['download'] as int? ?? 0,
        start: json['start'] as String? ?? '',
        chains: (json['chains'] as List<dynamic>? ?? []).cast<String>(),
        rule: json['rule'] as String? ?? '',
        rulePayload: json['rulePayload'] as String? ?? '',
      );
}

class ConnectionsSnapshot {
  final int downloadTotal;
  final int uploadTotal;
  final List<Connection> connections;

  const ConnectionsSnapshot({
    required this.downloadTotal,
    required this.uploadTotal,
    required this.connections,
  });

  factory ConnectionsSnapshot.fromJson(Map<String, dynamic> json) =>
      ConnectionsSnapshot(
        downloadTotal: json['downloadTotal'] as int? ?? 0,
        uploadTotal: json['uploadTotal'] as int? ?? 0,
        connections: (json['connections'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Connection.fromJson)
            .toList(),
      );
}
