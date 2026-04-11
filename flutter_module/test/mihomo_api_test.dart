import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/models/proxy.dart';
import 'package:flutter_module/models/proxy_group.dart';
import 'package:flutter_module/models/rule.dart';
import 'package:flutter_module/models/connection.dart';
import 'package:flutter_module/models/proxy_provider.dart';
import 'package:flutter_module/models/log_entry.dart';
import 'package:flutter_module/models/runtime_config.dart';
import 'package:flutter_module/models/traffic.dart';

void main() {
  group('Proxy.fromJson', () {
    test('parses all fields', () {
      final json = {
        'name': 'proxy1',
        'type': 'Shadowsocks',
        'history': [
          {'time': '2024-01-01T00:00:00Z', 'delay': 120, 'meanDelay': 115},
        ],
      };
      final proxy = Proxy.fromJson('proxy1', json);
      expect(proxy.name, 'proxy1');
      expect(proxy.type, 'Shadowsocks');
      expect(proxy.history.length, 1);
      expect(proxy.history.first.delay, 120);
    });

    test('handles empty history', () {
      final proxy = Proxy.fromJson('p', {'type': 'Direct', 'history': []});
      expect(proxy.history, isEmpty);
    });
  });

  group('ProxyHistory.fromJson', () {
    test('parses delay', () {
      final h = ProxyHistory.fromJson({'time': '2024-01-01T00:00:00Z', 'delay': 55, 'meanDelay': 50});
      expect(h.delay, 55);
    });

    test('defaults delay to 0 when absent', () {
      final h = ProxyHistory.fromJson({'time': '2024-01-01T00:00:00Z'});
      expect(h.delay, 0);
    });
  });

  group('ProxyGroup.fromJson', () {
    test('parses selector group', () {
      final json = {
        'type': 'Selector',
        'now': 'proxy1',
        'all': ['proxy1', 'proxy2'],
        'history': [],
      };
      final g = ProxyGroup.fromJson('MyGroup', json);
      expect(g.name, 'MyGroup');
      expect(g.type, 'Selector');
      expect(g.now, 'proxy1');
      expect(g.all, ['proxy1', 'proxy2']);
    });

    test('handles missing now', () {
      final g = ProxyGroup.fromJson('g', {
        'type': 'URLTest',
        'all': ['a'],
        'history': [],
      });
      expect(g.now, '');
    });
  });

  group('ProxiesResult.parse', () {
    test('separates groups from leaf proxies', () {
      final raw = {
        'proxies': {
          'GLOBAL': {
            'type': 'Selector',
            'now': 'proxy1',
            'all': ['proxy1', 'DIRECT'],
            'history': [],
          },
          'DIRECT': {'type': 'Direct', 'history': []},
          'proxy1': {'type': 'Shadowsocks', 'history': []},
        },
      };
      final result = ProxiesResult.parse(raw);
      expect(result.groups.keys, contains('GLOBAL'));
      expect(result.proxies.keys, containsAll(['DIRECT', 'proxy1']));
      expect(result.groups.containsKey('DIRECT'), isFalse);
    });
  });

  group('Rule.fromJson', () {
    test('parses all fields', () {
      final r = Rule.fromJson({
        'type': 'DOMAIN-SUFFIX',
        'payload': 'google.com',
        'proxy': 'DIRECT',
        'size': 0,
      });
      expect(r.type, 'DOMAIN-SUFFIX');
      expect(r.payload, 'google.com');
      expect(r.proxy, 'DIRECT');
    });
  });

  group('Connection.fromJson', () {
    test('parses full connection', () {
      final json = {
        'id': 'abc123',
        'metadata': {
          'network': 'tcp', 'type': 'HTTP',
          'sourceIP': '127.0.0.1', 'destinationIP': '1.1.1.1',
          'sourcePort': '12345', 'destinationPort': '80',
          'host': 'example.com', 'dnsMode': 'normal',
          'processName': '', 'uid': 0,
        },
        'upload': 100, 'download': 200,
        'start': '2024-01-01T00:00:00.000Z',
        'chains': ['proxy1', 'DIRECT'],
        'rule': 'DOMAIN-SUFFIX', 'rulePayload': 'example.com',
      };
      final c = Connection.fromJson(json);
      expect(c.id, 'abc123');
      expect(c.metadata.host, 'example.com');
      expect(c.upload, 100);
      expect(c.chains, ['proxy1', 'DIRECT']);
      expect(c.rule, 'DOMAIN-SUFFIX');
    });
  });

  group('ConnectionsSnapshot.fromJson', () {
    test('parses totals and list', () {
      final json = {
        'downloadTotal': 9999,
        'uploadTotal': 1111,
        'connections': <dynamic>[],
      };
      final snap = ConnectionsSnapshot.fromJson(json);
      expect(snap.downloadTotal, 9999);
      expect(snap.connections, isEmpty);
    });

    test('handles null connections field', () {
      final snap = ConnectionsSnapshot.fromJson({'downloadTotal': 0, 'uploadTotal': 0});
      expect(snap.connections, isEmpty);
    });
  });

  group('ProxyProvider.fromJson', () {
    test('parses name and vehicleType', () {
      final json = {
        'name': 'prov1', 'type': 'HTTP', 'vehicleType': 'HTTP',
        'updatedAt': '2024-01-01T00:00:00Z',
        'proxies': <dynamic>[],
        'subscriptionInfo': null,
      };
      final p = ProxyProvider.fromJson('prov1', json);
      expect(p.name, 'prov1');
      expect(p.vehicleType, 'HTTP');
    });
  });

  group('RuleProvider.fromJson', () {
    test('parses ruleCount', () {
      final json = {
        'name': 'rprov1', 'behavior': 'domain',
        'type': 'HTTP', 'vehicleType': 'HTTP',
        'updatedAt': '2024-01-01T00:00:00Z',
        'ruleCount': 500,
      };
      final rp = RuleProvider.fromJson('rprov1', json);
      expect(rp.ruleCount, 500);
      expect(rp.behavior, 'domain');
    });
  });

  group('LogEntry.fromJson', () {
    test('parses all fields', () {
      final e = LogEntry.fromJson({
        'type': 'INFO',
        'payload': 'Started engine',
        'time': '2024-01-01T00:00:00Z',
      });
      expect(e.type, 'INFO');
      expect(e.payload, 'Started engine');
      expect(e.time, '2024-01-01T00:00:00Z');
    });

    test('defaults missing fields to empty string', () {
      final e = LogEntry.fromJson({});
      expect(e.type, '');
      expect(e.payload, '');
    });
  });

  group('RuntimeConfig.fromJson', () {
    test('parses mode and toggles', () {
      final c = RuntimeConfig.fromJson({
        'mode': 'rule',
        'ipv6': true,
        'allow-lan': false,
        'log-level': 'info',
        'mixed-port': 7890,
        'external-controller': '127.0.0.1:9090',
      });
      expect(c.mode, 'rule');
      expect(c.ipv6, isTrue);
      expect(c.allowLan, isFalse);
      expect(c.logLevel, 'info');
      expect(c.mixedPort, 7890);
    });
  });

  group('MemoryInfo.fromJson', () {
    test('parses inuse and oslimit', () {
      final m = MemoryInfo.fromJson({'inuse': 12345, 'oslimit': 999999});
      expect(m.inuse, 12345);
      expect(m.oslimit, 999999);
    });
  });

  group('DnsQueryResult.fromJson', () {
    test('parses answers', () {
      final r = DnsQueryResult.fromJson({
        'Answer': [
          {'TTL': 300, 'data': '1.2.3.4', 'name': 'google.com.', 'type': 1},
        ],
        'Status': 0,
      });
      expect(r.status, 0);
      expect(r.answers.length, 1);
      expect(r.answers.first.data, '1.2.3.4');
    });

    test('handles null Answer field', () {
      final r = DnsQueryResult.fromJson({'Status': 2});
      expect(r.answers, isEmpty);
      expect(r.status, 2);
    });
  });

  group('MihomoTraffic.fromJson', () {
    test('parses up and down', () {
      final t = MihomoTraffic.fromJson({'up': 1024, 'down': 2048});
      expect(t.up, 1024);
      expect(t.down, 2048);
    });
  });
}
