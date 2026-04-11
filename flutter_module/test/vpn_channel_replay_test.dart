import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/services/vpn_channel.dart';
import 'package:flutter_module/models/proxy_group.dart';

void main() {
  group('VpnChannel.replaySelectionsOnConnect', () {
    test('calls selectProxy for each Selector group with a saved selection', () async {
      final called = <String, String>{};
      final groups = <String, ProxyGroup>{
        'Proxy': ProxyGroup(name: 'Proxy', type: 'Selector', now: 'auto', all: ['HK01', 'US01'], history: []),
        'Auto': ProxyGroup(name: 'Auto', type: 'URLTest', now: 'HK01', all: ['HK01', 'US01'], history: []),
      };
      final result = ProxiesResult(groups: groups, proxies: {});

      await VpnChannel.replaySelectionsOnConnect(
        result: result,
        selections: {'Proxy': 'US01'},
        selectProxy: (group, name) async => called[group] = name,
      );

      expect(called, {'Proxy': 'US01'});
    });

    test('skips groups whose first member resolves to DIRECT', () async {
      final called = <String, String>{};
      final groups = <String, ProxyGroup>{
        'Bypass': ProxyGroup(name: 'Bypass', type: 'Selector', now: 'DIRECT', all: ['DIRECT', 'HK01'], history: []),
        'Proxy': ProxyGroup(name: 'Proxy', type: 'Selector', now: 'HK01', all: ['HK01', 'US01'], history: []),
      };
      final result = ProxiesResult(groups: groups, proxies: {});

      await VpnChannel.replaySelectionsOnConnect(
        result: result,
        selections: {'Bypass': 'HK01', 'Proxy': 'US01'},
        selectProxy: (group, name) async => called[group] = name,
      );

      expect(called.containsKey('Bypass'), isFalse);
      expect(called['Proxy'], 'US01');
    });

    test('skips groups whose first member resolves to REJECT', () async {
      final called = <String, String>{};
      final groups = <String, ProxyGroup>{
        'Block': ProxyGroup(name: 'Block', type: 'Selector', now: 'REJECT', all: ['REJECT', 'HK01'], history: []),
        'Proxy': ProxyGroup(name: 'Proxy', type: 'Selector', now: 'HK01', all: ['HK01', 'US01'], history: []),
      };
      final result = ProxiesResult(groups: groups, proxies: {});

      await VpnChannel.replaySelectionsOnConnect(
        result: result,
        selections: {'Block': 'HK01', 'Proxy': 'US01'},
        selectProxy: (group, name) async => called[group] = name,
      );

      expect(called.containsKey('Block'), isFalse);
      expect(called['Proxy'], 'US01');
    });

    test('skips selection if node not in group.all', () async {
      final called = <String, String>{};
      final groups = <String, ProxyGroup>{
        'Proxy': ProxyGroup(name: 'Proxy', type: 'Selector', now: 'HK01', all: ['HK01', 'US01'], history: []),
      };
      final result = ProxiesResult(groups: groups, proxies: {});

      await VpnChannel.replaySelectionsOnConnect(
        result: result,
        selections: {'Proxy': 'SG01'},
        selectProxy: (group, name) async => called[group] = name,
      );

      expect(called, isEmpty);
    });

    test('skips non-Selector groups', () async {
      final called = <String, String>{};
      final groups = <String, ProxyGroup>{
        'Auto': ProxyGroup(name: 'Auto', type: 'URLTest', now: 'HK01', all: ['HK01', 'US01'], history: []),
        'Fallback': ProxyGroup(name: 'Fallback', type: 'Fallback', now: 'HK01', all: ['HK01', 'US01'], history: []),
      };
      final result = ProxiesResult(groups: groups, proxies: {});

      await VpnChannel.replaySelectionsOnConnect(
        result: result,
        selections: {'Auto': 'US01', 'Fallback': 'US01'},
        selectProxy: (group, name) async => called[group] = name,
      );

      expect(called, isEmpty);
    });
  });
}
