import 'proxy.dart';

class ProxyProvider {
  final String name;
  final String type;
  final String vehicleType;
  final String updatedAt;
  final List<Proxy> proxies;

  const ProxyProvider({
    required this.name,
    required this.type,
    required this.vehicleType,
    required this.updatedAt,
    required this.proxies,
  });

  factory ProxyProvider.fromJson(String name, Map<String, dynamic> json) =>
      ProxyProvider(
        name: name,
        type: json['type'] as String? ?? '',
        vehicleType: json['vehicleType'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
        proxies: (json['proxies'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map((m) => Proxy.fromJson(m['name'] as String? ?? '', m))
            .toList(),
      );
}

class RuleProvider {
  final String name;
  final String behavior;
  final String type;
  final String vehicleType;
  final String updatedAt;
  final int ruleCount;

  const RuleProvider({
    required this.name,
    required this.behavior,
    required this.type,
    required this.vehicleType,
    required this.updatedAt,
    required this.ruleCount,
  });

  factory RuleProvider.fromJson(String name, Map<String, dynamic> json) =>
      RuleProvider(
        name: name,
        behavior: json['behavior'] as String? ?? '',
        type: json['type'] as String? ?? '',
        vehicleType: json['vehicleType'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
        ruleCount: json['ruleCount'] as int? ?? 0,
      );
}
