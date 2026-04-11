import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_module/widgets/proxy_groups_section.dart';
import 'package:flutter_module/models/proxy_group.dart';
import 'package:flutter_module/models/proxy.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: CustomScrollView(slivers: [child])),
    );

ProxiesResult _twoGroups() => ProxiesResult(
      groups: {
        'Proxy': ProxyGroup(name: 'Proxy', type: 'Selector', now: 'HK01', all: ['HK01', 'US01'], history: []),
        'Auto': ProxyGroup(name: 'Auto', type: 'URLTest', now: 'HK01', all: ['HK01', 'US01'], history: []),
      },
      proxies: {
        'HK01': Proxy(name: 'HK01', type: 'Shadowsocks', history: [ProxyHistory(time: '', delay: 120)]),
        'US01': Proxy(name: 'US01', type: 'Shadowsocks', history: [ProxyHistory(time: '', delay: 280)]),
      },
    );

void main() {
  group('ProxyGroupsSection', () {
    testWidgets('renders group names and type badges', (tester) async {
      await tester.pumpWidget(_wrap(ProxyGroupsSection(
        isVpnConnected: true,
        initialSelections: const {},
        onSelectionsChanged: (_) {},
        getProxiesOverride: () async => _twoGroups(),
        selectProxyOverride: (a, b) async {},
        testGroupDelayOverride: (_) async => {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Proxy'), findsWidgets);
      expect(find.text('Selector'), findsOneWidget);
      expect(find.text('Auto'), findsWidgets);
      expect(find.text('URLTest'), findsOneWidget);
    });

    testWidgets('shows current selection in group header', (tester) async {
      await tester.pumpWidget(_wrap(ProxyGroupsSection(
        isVpnConnected: true,
        initialSelections: {'Proxy': 'HK01'},
        onSelectionsChanged: (_) {},
        getProxiesOverride: () async => _twoGroups(),
        selectProxyOverride: (a, b) async {},
        testGroupDelayOverride: (_) async => {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('HK01'), findsWidgets);
    });

    testWidgets('tapping node in Selector group calls selectProxyOverride', (tester) async {
      String? calledGroup;
      String? calledNode;

      await tester.pumpWidget(_wrap(ProxyGroupsSection(
        isVpnConnected: true,
        initialSelections: {'Proxy': 'HK01'},
        onSelectionsChanged: (_) {},
        getProxiesOverride: () async => _twoGroups(),
        selectProxyOverride: (g, n) async {
          calledGroup = g;
          calledNode = n;
        },
        testGroupDelayOverride: (_) async => {},
      )));
      await tester.pumpAndSettle();

      // Expand the Proxy group
      await tester.tap(find.text('Proxy').first);
      await tester.pumpAndSettle();

      // Tap US01
      await tester.tap(find.text('US01').first);
      await tester.pumpAndSettle();

      expect(calledGroup, 'Proxy');
      expect(calledNode, 'US01');
    });

    testWidgets('tapping node in group A does not change group B selection', (tester) async {
      final selections = <String, String>{'Proxy': 'HK01', 'Auto': 'HK01'};

      await tester.pumpWidget(_wrap(ProxyGroupsSection(
        isVpnConnected: true,
        initialSelections: Map.from(selections),
        onSelectionsChanged: (s) => selections.addAll(s),
        getProxiesOverride: () async => _twoGroups(),
        selectProxyOverride: (a, b) async {},
        testGroupDelayOverride: (_) async => {},
      )));
      await tester.pumpAndSettle();

      // Expand Proxy group
      await tester.tap(find.text('Proxy').first);
      await tester.pumpAndSettle();

      // Tap US01 in Proxy group
      await tester.tap(find.text('US01').first);
      await tester.pumpAndSettle();

      expect(selections['Auto'], 'HK01');
      expect(selections['Proxy'], 'US01');
    });

    testWidgets('URL test button calls testGroupDelayOverride', (tester) async {
      String? testedGroup;

      await tester.pumpWidget(_wrap(ProxyGroupsSection(
        isVpnConnected: true,
        initialSelections: const {},
        onSelectionsChanged: (_) {},
        getProxiesOverride: () async => _twoGroups(),
        selectProxyOverride: (a, b) async {},
        testGroupDelayOverride: (g) async {
          testedGroup = g;
          return {'HK01': 120, 'US01': 280};
        },
      )));
      await tester.pumpAndSettle();

      // Expand Proxy group to see URL test button
      await tester.tap(find.text('Proxy').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('URL Test All'));
      await tester.pumpAndSettle();

      expect(testedGroup, 'Proxy');
    });

    testWidgets('shows empty state when getProxies returns no groups', (tester) async {
      await tester.pumpWidget(_wrap(ProxyGroupsSection(
        isVpnConnected: false,
        initialSelections: const {},
        onSelectionsChanged: (_) {},
        getProxiesOverride: () async => ProxiesResult(groups: {}, proxies: {}),
        selectProxyOverride: (a, b) async {},
        testGroupDelayOverride: (_) async => {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('No proxy groups'), findsOneWidget);
    });

    testWidgets('latency chips show delay from proxy history', (tester) async {
      await tester.pumpWidget(_wrap(ProxyGroupsSection(
        isVpnConnected: true,
        initialSelections: const {},
        onSelectionsChanged: (_) {},
        getProxiesOverride: () async => _twoGroups(),
        selectProxyOverride: (a, b) async {},
        testGroupDelayOverride: (_) async => {},
      )));
      await tester.pumpAndSettle();

      // Expand Proxy group
      await tester.tap(find.text('Proxy').first);
      await tester.pumpAndSettle();

      expect(find.text('120ms'), findsOneWidget);
      expect(find.text('280ms'), findsOneWidget);
    });
  });
}
