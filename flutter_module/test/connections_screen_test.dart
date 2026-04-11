import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_module/screens/connections_screen.dart';
import 'package:flutter_module/models/connection.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      home: child,
    );

Connection _makeConn({
  String id = 'abc123',
  String host = 'example.com',
  String port = '443',
  List<String> chains = const ['PROXY', 'HK01'],
  String rule = 'DOMAIN-SUFFIX',
  String rulePayload = 'example.com',
  int upload = 1024,
  int download = 2048,
  String? start,
}) =>
    Connection(
      id: id,
      metadata: ConnectionMeta(
        network: 'tcp',
        type: 'HTTPS',
        sourceIP: '172.19.0.2',
        destinationIP: '93.184.216.34',
        sourcePort: '54321',
        destinationPort: port,
        host: host,
        dnsMode: 'normal',
        processName: '',
        uid: 0,
      ),
      upload: upload,
      download: download,
      start: start ?? DateTime.now().toUtc().toIso8601String(),
      chains: chains,
      rule: rule,
      rulePayload: rulePayload,
    );

ConnectionsSnapshot _snap(List<Connection> conns) => ConnectionsSnapshot(
      downloadTotal: conns.fold(0, (s, c) => s + c.download),
      uploadTotal: conns.fold(0, (s, c) => s + c.upload),
      connections: conns,
    );

void main() {
  group('ConnectionsScreen', () {
    testWidgets('shows empty state when no connections', (tester) async {
      await tester.pumpWidget(_wrap(ConnectionsScreen(
        getConnectionsOverride: () async => _snap([]),
        closeConnectionOverride: (_) async {},
        closeAllConnectionsOverride: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('No active connections'), findsOneWidget);
    });

    testWidgets('shows host:port in connection row', (tester) async {
      await tester.pumpWidget(_wrap(ConnectionsScreen(
        getConnectionsOverride: () async => _snap([_makeConn()]),
        closeConnectionOverride: (_) async {},
        closeAllConnectionsOverride: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('example.com'), findsWidgets);
      expect(find.textContaining('443'), findsWidgets);
    });

    testWidgets('shows last chain element in row', (tester) async {
      await tester.pumpWidget(_wrap(ConnectionsScreen(
        getConnectionsOverride: () async => _snap([
          _makeConn(chains: ['PROXY', 'HK01'], rule: 'DOMAIN-SUFFIX', rulePayload: 'example.com'),
        ]),
        closeConnectionOverride: (_) async {},
        closeAllConnectionsOverride: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('HK01'), findsWidgets);
    });

    testWidgets('swipe to dismiss calls closeConnectionOverride with correct id', (tester) async {
      String? closedId;
      await tester.pumpWidget(_wrap(ConnectionsScreen(
        getConnectionsOverride: () async => _snap([_makeConn(id: 'conn-id-1')]),
        closeConnectionOverride: (id) async => closedId = id,
        closeAllConnectionsOverride: () async {},
      )));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Dismissible).first, const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(closedId, 'conn-id-1');
    });

    testWidgets('close all button shows confirmation dialog', (tester) async {
      await tester.pumpWidget(_wrap(ConnectionsScreen(
        getConnectionsOverride: () async => _snap([_makeConn()]),
        closeConnectionOverride: (_) async {},
        closeAllConnectionsOverride: () async {},
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Close all active connections?'), findsOneWidget);
    });

    testWidgets('confirming close all calls closeAllConnectionsOverride', (tester) async {
      bool closedAll = false;
      await tester.pumpWidget(_wrap(ConnectionsScreen(
        getConnectionsOverride: () async => _snap([_makeConn()]),
        closeConnectionOverride: (_) async {},
        closeAllConnectionsOverride: () async => closedAll = true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close All'));
      await tester.pumpAndSettle();

      expect(closedAll, isTrue);
    });

    testWidgets('filter by host hides non-matching rows', (tester) async {
      await tester.pumpWidget(_wrap(ConnectionsScreen(
        getConnectionsOverride: () async => _snap([
          _makeConn(id: '1', host: 'example.com'),
          _makeConn(id: '2', host: 'google.com'),
        ]),
        closeConnectionOverride: (_) async {},
        closeAllConnectionsOverride: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('example.com'), findsWidgets);
      expect(find.textContaining('google.com'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'google');
      await tester.pumpAndSettle();

      expect(find.textContaining('google.com'), findsWidgets);
      expect(find.textContaining('example.com'), findsNothing);
    });

    testWidgets('shows upload and download bytes', (tester) async {
      await tester.pumpWidget(_wrap(ConnectionsScreen(
        getConnectionsOverride: () async => _snap([
          _makeConn(upload: 1536, download: 2048),
        ]),
        closeConnectionOverride: (_) async {},
        closeAllConnectionsOverride: () async {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('1.5 KB'), findsWidgets);
      expect(find.textContaining('2.0 KB'), findsWidgets);
    });
  });
}
