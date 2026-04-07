import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/services/vpn_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('io.github.madeye.meow/vpn');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('VpnChannel.updateProfileYaml', () {
    test('invokes updateProfileYaml with id and yamlContent', () async {
      MethodCall? captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await VpnChannel.instance.updateProfileYaml(42, 'a: 1\n');

      expect(captured, isNotNull);
      expect(captured!.method, 'updateProfileYaml');
      expect(captured!.arguments, {'id': 42, 'yamlContent': 'a: 1\n'});
    });
  });

  group('VpnChannel.revertProfileYaml', () {
    test('returns reverted yaml from native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'revertProfileYaml');
        expect(call.arguments, {'id': 9});
        return 'pristine: true\n';
      });

      final result = await VpnChannel.instance.revertProfileYaml(9);
      expect(result, 'pristine: true\n');
    });

    test('returns empty string when native returns null', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final result = await VpnChannel.instance.revertProfileYaml(1);
      expect(result, '');
    });
  });
}
