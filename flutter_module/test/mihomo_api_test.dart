import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/models/proxy.dart';
import 'package:flutter_module/models/proxy_group.dart';
import 'package:flutter_module/models/rule.dart';
import 'package:flutter_module/models/connection.dart';
import 'package:flutter_module/models/proxy_provider.dart';
import 'package:flutter_module/models/log_entry.dart';
import 'package:flutter_module/models/runtime_config.dart';
import 'package:flutter_module/models/traffic.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_module/services/mihomo_api.dart';

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

  group('MihomoApi REST methods', () {
    MihomoApi makeApi(Map<String, http.Response> responses) {
      final client = MockClient((request) async {
        final key = '${request.method} ${request.url.path}';
        return responses[key] ?? http.Response('{"error":"not found"}', 404);
      });
      return MihomoApi.withClient(client);
    }

    test('getProxies returns ProxiesResult', () async {
      final api = makeApi({
        'GET /proxies': http.Response(
          jsonEncode({
            'proxies': {
              'MyGroup': {
                'type': 'Selector',
                'now': 'proxy1',
                'all': ['proxy1'],
                'history': [],
              },
              'proxy1': {'type': 'Shadowsocks', 'history': []},
            },
          }),
          200,
        ),
      });
      final result = await api.getProxies();
      expect(result.groups.containsKey('MyGroup'), isTrue);
      expect(result.proxies.containsKey('proxy1'), isTrue);
    });

    test('selectProxy sends PUT with name body', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('', 204);
      });
      final api = MihomoApi.withClient(client);
      await api.selectProxy('MyGroup', 'proxy1');
      expect(captured!.method, 'PUT');
      expect(captured!.url.path, '/proxies/MyGroup');
      expect(jsonDecode(captured!.body)['name'], 'proxy1');
    });

    test('getRules returns list of Rule', () async {
      final api = makeApi({
        'GET /rules': http.Response(
          jsonEncode({
            'rules': [
              {'type': 'DOMAIN-SUFFIX', 'payload': 'google.com', 'proxy': 'DIRECT'},
            ],
          }),
          200,
        ),
      });
      final rules = await api.getRules();
      expect(rules.length, 1);
      expect(rules.first.type, 'DOMAIN-SUFFIX');
    });

    test('getConnections returns ConnectionsSnapshot', () async {
      final api = makeApi({
        'GET /connections': http.Response(
          jsonEncode({'downloadTotal': 100, 'uploadTotal': 50, 'connections': []}),
          200,
        ),
      });
      final snap = await api.getConnections();
      expect(snap.downloadTotal, 100);
      expect(snap.connections, isEmpty);
    });

    test('closeAllConnections sends DELETE /connections', () async {
      http.BaseRequest? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('', 204);
      });
      await MihomoApi.withClient(client).closeAllConnections();
      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/connections');
    });

    test('closeConnection sends DELETE /connections/id', () async {
      http.BaseRequest? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('', 204);
      });
      await MihomoApi.withClient(client).closeConnection('abc123');
      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/connections/abc123');
    });

    test('getConfigs returns RuntimeConfig', () async {
      final api = makeApi({
        'GET /configs': http.Response(
          jsonEncode({
            'mode': 'rule', 'ipv6': false, 'allow-lan': true,
            'log-level': 'info', 'mixed-port': 7890,
            'external-controller': '127.0.0.1:9090',
          }),
          200,
        ),
      });
      final config = await api.getConfigs();
      expect(config.mode, 'rule');
      expect(config.allowLan, isTrue);
    });

    test('patchConfigs sends PATCH with body', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('', 204);
      });
      await MihomoApi.withClient(client).patchConfigs({'mode': 'global'});
      expect(captured!.method, 'PATCH');
      expect(captured!.url.path, '/configs');
      expect(jsonDecode(captured!.body)['mode'], 'global');
    });

    test('getMemory returns MemoryInfo', () async {
      final api = makeApi({
        'GET /memory': http.Response(
          jsonEncode({'inuse': 12345, 'oslimit': 999999}),
          200,
        ),
      });
      final mem = await api.getMemory();
      expect(mem.inuse, 12345);
    });

    test('dnsQuery returns DnsQueryResult', () async {
      final api = makeApi({
        'GET /dns/query': http.Response(
          jsonEncode({'Answer': [], 'Status': 0}),
          200,
        ),
      });
      final r = await api.dnsQuery('google.com');
      expect(r.status, 0);
    });

    test('getProxyProviders returns map of ProxyProvider', () async {
      final api = makeApi({
        'GET /providers/proxies': http.Response(
          jsonEncode({
            'providers': {
              'prov1': {
                'name': 'prov1', 'type': 'HTTP', 'vehicleType': 'HTTP',
                'updatedAt': '2024-01-01T00:00:00Z', 'proxies': [],
              },
            },
          }),
          200,
        ),
      });
      final providers = await api.getProxyProviders();
      expect(providers.containsKey('prov1'), isTrue);
    });

    test('getRuleProviders returns map of RuleProvider', () async {
      final api = makeApi({
        'GET /providers/rules': http.Response(
          jsonEncode({
            'providers': {
              'rprov1': {
                'name': 'rprov1', 'behavior': 'domain',
                'type': 'HTTP', 'vehicleType': 'HTTP',
                'updatedAt': '2024-01-01T00:00:00Z', 'ruleCount': 100,
              },
            },
          }),
          200,
        ),
      });
      final providers = await api.getRuleProviders();
      expect(providers['rprov1']?.ruleCount, 100);
    });

    test('testProxyDelay sends GET with url and timeout params', () async {
      http.BaseRequest? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'delay': 150}), 200);
      });
      final delay = await MihomoApi.withClient(client).testProxyDelay('proxy1');
      expect(delay, 150);
      expect(captured!.url.path, '/proxies/proxy1/delay');
      expect(captured!.url.queryParameters['url'], isNotNull);
    });

    test('testGroupDelay returns map of name to delay', () async {
      http.BaseRequest? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'proxy1': 100, 'proxy2': 200}), 200);
      });
      final delays = await MihomoApi.withClient(client).testGroupDelay('MyGroup');
      expect(delays['proxy1'], 100);
      expect(captured!.url.path, '/group/MyGroup/delay');
    });
  });

  group('MihomoApi stream types', () {
    test('streamLogs returns Stream<LogEntry>', () {
      final api = MihomoApi.withClient(http.Client());
      expect(api.streamLogs(), isA<Stream<LogEntry>>());
    });

    test('streamTraffic returns Stream<MihomoTraffic>', () {
      final api = MihomoApi.withClient(http.Client());
      expect(api.streamTraffic(), isA<Stream<MihomoTraffic>>());
    });
  });
}
