import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/models/log_entry.dart';
import 'package:flutter_module/screens/logs_screen.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: child,
    );

void main() {
  group('LogsScreen', () {
    testWidgets('shows empty state when stream has no entries', (tester) async {
      final controller = StreamController<LogEntry>();
      await tester.pumpWidget(_wrap(
        LogsScreen(
          streamLogsOverride: ({level = 'info'}) => controller.stream,
        ),
      ));
      await tester.pump();
      expect(find.text('No logs yet'), findsOneWidget);
      await controller.close();
    });

    testWidgets('shows log entry payload when stream emits', (tester) async {
      final controller = StreamController<LogEntry>();
      await tester.pumpWidget(_wrap(
        LogsScreen(
          streamLogsOverride: ({level = 'info'}) => controller.stream,
        ),
      ));
      controller.add(const LogEntry(
          type: 'INFO', payload: 'engine started', time: ''));
      await tester.pump();
      expect(find.text('engine started'), findsOneWidget);
      expect(find.text('No logs yet'), findsNothing);
      await controller.close();
    });

    testWidgets('clear button empties the log list', (tester) async {
      final controller = StreamController<LogEntry>();
      await tester.pumpWidget(_wrap(
        LogsScreen(
          streamLogsOverride: ({level = 'info'}) => controller.stream,
        ),
      ));
      controller.add(const LogEntry(type: 'INFO', payload: 'hello', time: ''));
      await tester.pump();
      expect(find.text('hello'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      expect(find.text('hello'), findsNothing);
      expect(find.text('No logs yet'), findsOneWidget);
      await controller.close();
    });

    testWidgets('pause prevents new entries from appearing', (tester) async {
      final controller = StreamController<LogEntry>();
      await tester.pumpWidget(_wrap(
        LogsScreen(
          streamLogsOverride: ({level = 'info'}) => controller.stream,
        ),
      ));

      // Pause
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();

      controller.add(const LogEntry(type: 'INFO', payload: 'paused msg', time: ''));
      await tester.pump();

      // Nothing should appear while paused
      expect(find.text('paused msg'), findsNothing);
      await controller.close();
    });

    testWidgets('level filter dropdown shows current level', (tester) async {
      final controller = StreamController<LogEntry>();
      await tester.pumpWidget(_wrap(
        LogsScreen(
          streamLogsOverride: ({level = 'info'}) => controller.stream,
        ),
      ));
      await tester.pump();
      // The dropdown shows the current level (Info)
      expect(find.text('Info'), findsOneWidget);
      await controller.close();
    });

    testWidgets('level color: ERROR entries render a badge', (tester) async {
      final controller = StreamController<LogEntry>();
      await tester.pumpWidget(_wrap(
        LogsScreen(
          streamLogsOverride: ({level = 'info'}) => controller.stream,
        ),
      ));
      controller.add(const LogEntry(type: 'ERROR', payload: 'fail', time: ''));
      await tester.pump();
      // The badge text for an ERROR entry should be 'ERRO' (truncated to 4)
      expect(find.text('ERRO'), findsOneWidget);
      await controller.close();
    });

    testWidgets('caps buffer at 1000 entries', (tester) async {
      final controller = StreamController<LogEntry>();
      await tester.pumpWidget(_wrap(
        LogsScreen(
          streamLogsOverride: ({level = 'info'}) => controller.stream,
        ),
      ));

      // Emit 1005 entries
      for (int i = 0; i < 1005; i++) {
        controller.add(LogEntry(type: 'INFO', payload: 'msg$i', time: ''));
      }
      await tester.pump();

      // Only 1000 items should be in the list
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.semanticChildCount, lessThanOrEqualTo(1000));
      await controller.close();
    });

    testWidgets('level change restarts stream with new level', (tester) async {
      final levels = <String>[];
      StreamController<LogEntry>? ctrl;

      await tester.pumpWidget(_wrap(
        LogsScreen(
          streamLogsOverride: ({level = 'info'}) {
            levels.add(level);
            ctrl = StreamController<LogEntry>();
            return ctrl!.stream;
          },
        ),
      ));
      await tester.pump();
      expect(levels, ['info']); // initial subscription at info

      // Open the dropdown and select Error
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Error').last);
      await tester.pumpAndSettle();

      expect(levels.last, 'error');
      await ctrl?.close();
    });
  });
}
