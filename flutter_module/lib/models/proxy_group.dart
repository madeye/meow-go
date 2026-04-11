import 'package:yaml/yaml.dart';
import 'proxy.dart';

/// Group types as reported by mihomo's /proxies endpoint.
const _kGroupTypes = {
  'Selector',
  'URLTest',
  'Fallback',
  'LoadBalance',
  'Relay',
};

/// Map clash YAML group type strings to mihomo API strings.
String _normalizeGroupType(String type) {
  switch (type) {
    case 'select':
      return 'Selector';
    case 'url-test':
      return 'URLTest';
    case 'fallback':
      return 'Fallback';
    case 'load-balance':
      return 'LoadBalance';
    case 'relay':
      return 'Relay';
    default:
      return type;
  }
}

class ProxyGroup {
  final String name;
  final String type; // Selector | URLTest | Fallback | LoadBalance | Relay
  final String now;  // currently selected member name
  final List<String> all;
  final List<ProxyHistory> history;

  const ProxyGroup({
    required this.name,
    required this.type,
    required this.now,
    required this.all,
    required this.history,
  });

  factory ProxyGroup.fromJson(String name, Map<String, dynamic> json) =>
      ProxyGroup(
        name: name,
        type: json['type'] as String? ?? '',
        now: json['now'] as String? ?? '',
        all: (json['all'] as List<dynamic>? ?? []).cast<String>(),
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => ProxyHistory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Result of GET /proxies, split into proxy groups and leaf proxies.
class ProxiesResult {
  final Map<String, ProxyGroup> groups;
  final Map<String, Proxy> proxies;

  const ProxiesResult({required this.groups, required this.proxies});

  /// Parse the raw /proxies JSON response body.
  factory ProxiesResult.parse(Map<String, dynamic> json) {
    final raw = (json['proxies'] as Map<String, dynamic>? ?? {});
    final groups = <String, ProxyGroup>{};
    final proxies = <String, Proxy>{};
    for (final entry in raw.entries) {
      if (entry.value is! Map<String, dynamic>) continue;
      final data = entry.value as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';
      if (_kGroupTypes.contains(type)) {
        groups[entry.key] = ProxyGroup.fromJson(entry.key, data);
      } else {
        proxies[entry.key] = Proxy.fromJson(entry.key, data);
      }
    }
    return ProxiesResult(groups: groups, proxies: proxies);
  }

  /// Parse a clash config YAML string into a ProxiesResult for offline
  /// display when the embedded engine isn't running (e.g. VPN is off).
  /// Returns empty groups/proxies on any parse error. No history or delay
  /// data — those only come from the live /proxies endpoint.
  factory ProxiesResult.fromYaml(String yamlContent) {
    if (yamlContent.isEmpty) {
      return const ProxiesResult(groups: {}, proxies: {});
    }
    try {
      final doc = loadYaml(yamlContent);
      if (doc is! Map) return const ProxiesResult(groups: {}, proxies: {});

      final proxies = <String, Proxy>{};
      final rawProxies = doc['proxies'];
      if (rawProxies is List) {
        for (final p in rawProxies) {
          if (p is Map && p['name'] != null) {
            final name = p['name'].toString();
            final type = (p['type'] ?? '').toString();
            proxies[name] = Proxy(name: name, type: type, history: const []);
          }
        }
      }
      // DIRECT / REJECT are built-in members of clash proxy groups.
      proxies.putIfAbsent(
        'DIRECT',
        () => const Proxy(name: 'DIRECT', type: 'Direct', history: []),
      );
      proxies.putIfAbsent(
        'REJECT',
        () => const Proxy(name: 'REJECT', type: 'Reject', history: []),
      );

      final groups = <String, ProxyGroup>{};
      final rawGroups = doc['proxy-groups'];
      if (rawGroups is List) {
        for (final g in rawGroups) {
          if (g is Map && g['name'] != null) {
            final name = g['name'].toString();
            final type = _normalizeGroupType((g['type'] ?? '').toString());
            final all = <String>[];
            final members = g['proxies'];
            if (members is List) {
              for (final m in members) {
                all.add(m.toString());
              }
            }
            groups[name] = ProxyGroup(
              name: name,
              type: type,
              now: all.isNotEmpty ? all.first : '',
              all: all,
              history: const [],
            );
          }
        }
      }

      return ProxiesResult(groups: groups, proxies: proxies);
    } catch (_) {
      return const ProxiesResult(groups: {}, proxies: {});
    }
  }
}
