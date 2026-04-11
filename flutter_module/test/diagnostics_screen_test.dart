import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_module/screens/diagnostics_screen.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en')],
  home: child,
);

void main() {
  group('DiagnosticsScreen', () {
    testWidgets('shows 4 Run buttons initially', (tester) async {
      await tester.pumpWidget(_wrap(const DiagnosticsScreen()));
      await tester.pump();

      expect(find.text('Run'), findsNWidgets(4));
    });

    testWidgets('shows em-dash placeholder for unrun tests', (tester) async {
      await tester.pumpWidget(_wrap(const DiagnosticsScreen()));
      await tester.pump();

      expect(find.text('—'), findsNWidgets(4));
    });

    testWidgets('Direct TCP run shows result after tap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DiagnosticsScreen(
            directTcpOverride: () async => 'OK 1.1.1.1:80 (32ms)',
            proxyHttpOverride: () async => '—',
            dnsResolverOverride: () async => '—',
            dnsQueryOverride: () async => '—',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Run').first);
      await tester.pumpAndSettle();

      expect(find.text('OK 1.1.1.1:80 (32ms)'), findsOneWidget);
    });

    testWidgets('Proxy HTTP run shows result after tap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DiagnosticsScreen(
            directTcpOverride: () async => '—',
            proxyHttpOverride: () async => 'OK http://... 204 (310ms)',
            dnsResolverOverride: () async => '—',
            dnsQueryOverride: () async => '—',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Run').at(1));
      await tester.pumpAndSettle();

      expect(find.text('OK http://... 204 (310ms)'), findsOneWidget);
    });

    testWidgets('DNS resolver run shows result after tap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DiagnosticsScreen(
            directTcpOverride: () async => '—',
            proxyHttpOverride: () async => '—',
            dnsResolverOverride: () async =>
                'OK 127.0.0.1:1053 -> [93.184.216.34] (45ms)',
            dnsQueryOverride: () async => '—',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Run').at(2));
      await tester.pumpAndSettle();

      expect(find.textContaining('127.0.0.1:1053'), findsAtLeastNWidgets(1));
    });

    testWidgets('DNS query run shows formatted result', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DiagnosticsScreen(
            directTcpOverride: () async => '—',
            proxyHttpOverride: () async => '—',
            dnsResolverOverride: () async => '—',
            dnsQueryOverride: () async => 'OK: 93.184.216.34',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Run').at(3));
      await tester.pumpAndSettle();

      expect(find.text('OK: 93.184.216.34'), findsOneWidget);
    });

    testWidgets('button is disabled while test is running', (tester) async {
      final completer = Completer<String>();
      await tester.pumpWidget(
        _wrap(
          DiagnosticsScreen(
            directTcpOverride: () => completer.future,
            proxyHttpOverride: () async => '—',
            dnsResolverOverride: () async => '—',
            dnsQueryOverride: () async => '—',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Run').first);
      await tester.pump();

      expect(find.text('Running...'), findsOneWidget);

      completer.complete('OK done');
      await tester.pumpAndSettle();
    });
  });
}
