import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/models/profile.dart';

void main() {
  group('ClashProfile.selectedProxies', () {
    test('fromMap parses JSON map', () {
      final p = ClashProfile.fromMap({
        'id': 1,
        'name': 'test',
        'url': '',
        'yamlContent': '',
        'selected': false,
        'lastUpdated': 0,
        'tx': 0,
        'rx': 0,
        'selectedProxy': '',
        'yamlBackup': '',
        'selectedProxies': '{"Proxy":"HK01","Fallback":"US01"}',
      });
      expect(p.selectedProxies, {'Proxy': 'HK01', 'Fallback': 'US01'});
    });

    test('fromMap defaults to empty map when key absent', () {
      final p = ClashProfile.fromMap({'id': 1});
      expect(p.selectedProxies, isEmpty);
    });

    test('toMap serializes map to JSON string', () {
      final p = ClashProfile(selectedProxies: {'A': 'node1'});
      final m = p.toMap();
      expect(m['selectedProxies'], '{"A":"node1"}');
    });

    test('roundtrip preserves all entries', () {
      final original = ClashProfile(selectedProxies: {'G1': 'n1', 'G2': 'n2'});
      final roundtripped = ClashProfile.fromMap(original.toMap());
      expect(roundtripped.selectedProxies, original.selectedProxies);
    });
  });
}
