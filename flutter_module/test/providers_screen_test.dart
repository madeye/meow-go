import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_module/screens/providers_screen.dart';
import 'package:flutter_module/models/proxy_provider.dart';
import 'package:flutter_module/models/proxy.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en')],
  home: child,
);

ProxyProvider _proxyProvider(String name, {int proxyCount = 3}) =>
    ProxyProvider(
      name: name,
      type: 'Proxy',
      vehicleType: 'HTTP',
      updatedAt: '2026-04-11T10:00:00.000Z',
      proxies: List.generate(
        proxyCount,
        (i) => Proxy(name: 'node$i', type: 'ss', history: const []),
      ),
    );

RuleProvider _ruleProvider(String name, {int ruleCount = 100}) => RuleProvider(
  name: name,
  behavior: 'domain',
  type: 'Rule',
  vehicleType: 'HTTP',
  updatedAt: '2026-04-11T09:00:00.000Z',
  ruleCount: ruleCount,
);

void main() {
  group('ProvidersScreen', () {
    testWidgets('shows noProviders when both lists are empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProvidersScreen(
            getProxyProvidersOverride: () async => {},
            getRuleProvidersOverride: () async => {},
            updateProxyProviderOverride: (_) async {},
            updateRuleProviderOverride: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No providers'), findsOneWidget);
    });

    testWidgets('shows proxy provider name and proxy count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProvidersScreen(
            getProxyProvidersOverride: () async => {
              'MyProvider': _proxyProvider('MyProvider', proxyCount: 5),
            },
            getRuleProvidersOverride: () async => {},
            updateProxyProviderOverride: (_) async {},
            updateRuleProviderOverride: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MyProvider'), findsOneWidget);
      expect(find.textContaining('5 proxies'), findsOneWidget);
    });

    testWidgets('shows rule provider name and rule count', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProvidersScreen(
            getProxyProvidersOverride: () async => {},
            getRuleProvidersOverride: () async => {
              'BlockList': _ruleProvider('BlockList', ruleCount: 42),
            },
            updateProxyProviderOverride: (_) async {},
            updateRuleProviderOverride: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BlockList'), findsOneWidget);
      expect(find.textContaining('42 rules'), findsOneWidget);
    });

    testWidgets('shows updatedAt date for proxy provider', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProvidersScreen(
            getProxyProvidersOverride: () async => {'P1': _proxyProvider('P1')},
            getRuleProvidersOverride: () async => {},
            updateProxyProviderOverride: (_) async {},
            updateRuleProviderOverride: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2026-04-11'), findsOneWidget);
    });

    testWidgets(
      'tapping Update on proxy provider calls updateProxyProviderOverride',
      (tester) async {
        String? updated;
        await tester.pumpWidget(
          _wrap(
            ProvidersScreen(
              getProxyProvidersOverride: () async => {
                'MyProvider': _proxyProvider('MyProvider'),
              },
              getRuleProvidersOverride: () async => {},
              updateProxyProviderOverride: (name) async => updated = name,
              updateRuleProviderOverride: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        expect(updated, 'MyProvider');
      },
    );

    testWidgets(
      'tapping Update on rule provider calls updateRuleProviderOverride',
      (tester) async {
        String? updated;
        await tester.pumpWidget(
          _wrap(
            ProvidersScreen(
              getProxyProvidersOverride: () async => {},
              getRuleProvidersOverride: () async => {
                'BlockList': _ruleProvider('BlockList'),
              },
              updateProxyProviderOverride: (_) async {},
              updateRuleProviderOverride: (name) async => updated = name,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        expect(updated, 'BlockList');
      },
    );

    testWidgets('shows both section headers when both have providers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProvidersScreen(
            getProxyProvidersOverride: () async => {'P1': _proxyProvider('P1')},
            getRuleProvidersOverride: () async => {'R1': _ruleProvider('R1')},
            updateProxyProviderOverride: (_) async {},
            updateRuleProviderOverride: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Proxy Providers'), findsOneWidget);
      expect(find.text('Rule Providers'), findsOneWidget);
    });
  });
}
