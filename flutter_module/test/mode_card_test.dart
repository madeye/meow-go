import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_module/widgets/mode_card.dart';
import 'package:flutter_module/models/runtime_config.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

RuntimeConfig _config({String mode = 'rule', bool allowLan = false, bool ipv6 = false}) =>
    RuntimeConfig(
      mode: mode,
      ipv6: ipv6,
      allowLan: allowLan,
      logLevel: 'info',
      mixedPort: 7890,
      externalController: '127.0.0.1:9090',
    );

void main() {
  group('ModeCard', () {
    testWidgets('shows current mode from getConfigs', (tester) async {
      await tester.pumpWidget(_wrap(ModeCard(
        isVpnConnected: true,
        getConfigsOverride: () async => _config(mode: 'global'),
        patchConfigsOverride: (_) async {},
      )));
      await tester.pumpAndSettle();

      final button = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(button.selected, {'global'});
    });

    testWidgets('selecting a mode calls patchConfigs with correct key', (tester) async {
      Map<String, dynamic>? patched;
      await tester.pumpWidget(_wrap(ModeCard(
        isVpnConnected: true,
        getConfigsOverride: () async => _config(mode: 'rule'),
        patchConfigsOverride: (m) async => patched = m,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Global'));
      await tester.pumpAndSettle();

      expect(patched, {'mode': 'global'});
    });

    testWidgets('segments are disabled when VPN disconnected', (tester) async {
      await tester.pumpWidget(_wrap(ModeCard(
        isVpnConnected: false,
        getConfigsOverride: () async => _config(mode: 'rule'),
        patchConfigsOverride: (_) async {},
      )));
      await tester.pumpAndSettle();

      final button = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(button.onSelectionChanged, isNull);
    });

    testWidgets('reloads config when VPN connects', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(_wrap(ModeCard(
        isVpnConnected: false,
        getConfigsOverride: () async { callCount++; return _config(mode: 'rule'); },
        patchConfigsOverride: (_) async {},
      )));
      await tester.pumpAndSettle();

      final initial = callCount;

      await tester.pumpWidget(_wrap(ModeCard(
        isVpnConnected: true,
        getConfigsOverride: () async { callCount++; return _config(mode: 'global'); },
        patchConfigsOverride: (_) async {},
      )));
      await tester.pumpAndSettle();

      expect(callCount, greaterThan(initial));
    });
  });
}
