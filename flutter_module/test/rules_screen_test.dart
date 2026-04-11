import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_module/screens/rules_screen.dart';
import 'package:flutter_module/models/rule.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en')],
  home: child,
);

List<Rule> _sampleRules() => [
  const Rule(type: 'DOMAIN', payload: 'google.com', proxy: 'Proxy'),
  const Rule(type: 'IP-CIDR', payload: '8.8.8.8/32', proxy: 'DIRECT'),
  const Rule(type: 'DOMAIN-SUFFIX', payload: 'youtube.com', proxy: 'REJECT'),
  const Rule(type: 'MATCH', payload: '', proxy: 'DIRECT'),
];

void main() {
  group('RulesScreen', () {
    testWidgets('shows noRules when list is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(RulesScreen(getRulesOverride: () async => [])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No rules found'), findsOneWidget);
    });

    testWidgets('shows all rules after load', (tester) async {
      await tester.pumpWidget(
        _wrap(RulesScreen(getRulesOverride: () async => _sampleRules())),
      );
      await tester.pumpAndSettle();

      expect(find.text('google.com'), findsOneWidget);
      expect(find.text('8.8.8.8/32'), findsOneWidget);
      expect(find.text('youtube.com'), findsOneWidget);
    });

    testWidgets('shows rule count in AppBar title after load', (tester) async {
      await tester.pumpWidget(
        _wrap(RulesScreen(getRulesOverride: () async => _sampleRules())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('4 rules'), findsOneWidget);
    });

    testWidgets('filter by type narrows results', (tester) async {
      await tester.pumpWidget(
        _wrap(RulesScreen(getRulesOverride: () async => _sampleRules())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ip-cidr');
      await tester.pump();

      expect(find.text('8.8.8.8/32'), findsOneWidget);
      expect(find.text('google.com'), findsNothing);
    });

    testWidgets('filter by payload narrows results', (tester) async {
      await tester.pumpWidget(
        _wrap(RulesScreen(getRulesOverride: () async => _sampleRules())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'youtube');
      await tester.pump();

      expect(find.text('youtube.com'), findsOneWidget);
      expect(find.text('google.com'), findsNothing);
    });

    testWidgets('filter by proxy narrows results', (tester) async {
      await tester.pumpWidget(
        _wrap(RulesScreen(getRulesOverride: () async => _sampleRules())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'reject');
      await tester.pump();

      expect(find.text('youtube.com'), findsOneWidget);
      expect(find.text('google.com'), findsNothing);
    });

    testWidgets('MATCH rule shows type chip even with empty payload', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(RulesScreen(getRulesOverride: () async => _sampleRules())),
      );
      await tester.pumpAndSettle();

      expect(find.text('MATCH'), findsOneWidget);
    });
  });
}
