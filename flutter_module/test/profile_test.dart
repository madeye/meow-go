import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_module/models/profile.dart';

void main() {
  group('ClashProfile.yamlBackup', () {
    test('round-trips through fromMap/toMap', () {
      final original = ClashProfile(
        id: 7,
        name: 'test',
        url: 'https://example.com/c.yaml',
        yamlContent: 'edited:\n  foo: 1',
        yamlBackup: 'pristine:\n  foo: 0',
        selected: true,
        lastUpdated: 1700000000,
        selectedProxy: 'JP',
      );
      final copy = ClashProfile.fromMap(original.toMap());
      expect(copy.id, 7);
      expect(copy.yamlContent, 'edited:\n  foo: 1');
      expect(copy.yamlBackup, 'pristine:\n  foo: 0');
      expect(copy.selected, true);
      expect(copy.selectedProxy, 'JP');
    });

    test('fromMap defaults missing yamlBackup to empty string', () {
      final p = ClashProfile.fromMap(<String, dynamic>{
        'id': 1,
        'name': 'n',
        'yamlContent': 'a: 1',
      });
      expect(p.yamlBackup, '');
    });
  });

  group('ClashProfile.hasBackup', () {
    test('false when backup is empty', () {
      final p = ClashProfile(yamlContent: 'a: 1', yamlBackup: '');
      expect(p.hasBackup, isFalse);
    });

    test('false when content matches backup (nothing to revert to)', () {
      final p = ClashProfile(yamlContent: 'a: 1', yamlBackup: 'a: 1');
      expect(p.hasBackup, isFalse);
    });

    test('true when content has been edited away from the backup', () {
      final p = ClashProfile(yamlContent: 'a: 2', yamlBackup: 'a: 1');
      expect(p.hasBackup, isTrue);
    });
  });
}
