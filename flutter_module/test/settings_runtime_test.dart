import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_module/screens/settings_screen.dart';
import 'package:flutter_module/models/runtime_config.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      home: child,
    );

RuntimeConfig _config({bool allowLan = false, bool ipv6 = false}) =>
    RuntimeConfig(
      mode: 'rule',
      ipv6: ipv6,
      allowLan: allowLan,
      logLevel: 'info',
      mixedPort: 7890,
      externalController: '127.0.0.1:9090',
    );

void main() {
  group('SettingsScreen runtime section', () {
    testWidgets('shows Allow LAN switch with value from getConfigs', (tester) async {
      await tester.pumpWidget(_wrap(SettingsScreen(
        getConfigsOverride: () async => _config(allowLan: true),
        patchConfigsOverride: (_) async {},
      )));
      await tester.pumpAndSettle();

      final switches = tester
          .widgetList<Switch>(find.byType(Switch))
          .toList();
      expect(switches.any((s) => s.value == true), isTrue);
    });

    testWidgets('shows IPv6 switch with value from getConfigs', (tester) async {
      await tester.pumpWidget(_wrap(SettingsScreen(
        getConfigsOverride: () async => _config(ipv6: true),
        patchConfigsOverride: (_) async {},
      )));
      await tester.pumpAndSettle();

      final switches = tester
          .widgetList<Switch>(find.byType(Switch))
          .toList();
      expect(switches.any((s) => s.value == true), isTrue);
    });

    testWidgets('toggling Allow LAN calls patchConfigs with allow-lan key', (tester) async {
      Map<String, dynamic>? patched;
      await tester.pumpWidget(_wrap(SettingsScreen(
        getConfigsOverride: () async => _config(allowLan: false),
        patchConfigsOverride: (m) async => patched = m,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('switch_allow_lan')));
      await tester.pumpAndSettle();

      expect(patched, containsPair('allow-lan', true));
    });

    testWidgets('toggling IPv6 calls patchConfigs with ipv6 key', (tester) async {
      Map<String, dynamic>? patched;
      await tester.pumpWidget(_wrap(SettingsScreen(
        getConfigsOverride: () async => _config(ipv6: false),
        patchConfigsOverride: (m) async => patched = m,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('switch_ipv6')));
      await tester.pumpAndSettle();

      expect(patched, containsPair('ipv6', true));
    });
  });
}
