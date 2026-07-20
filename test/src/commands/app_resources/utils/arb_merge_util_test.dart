import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/utils/utils.dart';

void main() {
  group('ArbMergeUtil.mergeArb', () {
    test('adds a key that only exists in the downloaded map', () {
      final local = <String, dynamic>{'@@locale': 'en', 'foo': 'Foo'};
      final downloaded = <String, dynamic>{'@@locale': 'en', 'foo': 'Foo', 'bar': 'Bar'};

      final result = ArbMergeUtil.mergeArb(local, downloaded);

      expect(result, {'@@locale': 'en', 'foo': 'Foo', 'bar': 'Bar'});
    });

    test('downloaded value overwrites a conflicting local value', () {
      final local = <String, dynamic>{'foo': 'Old Foo'};
      final downloaded = <String, dynamic>{'foo': 'New Foo'};

      final result = ArbMergeUtil.mergeArb(local, downloaded);

      expect(result, {'foo': 'New Foo'});
    });

    test('keeps a key that only exists locally (not yet uploaded)', () {
      final local = <String, dynamic>{'foo': 'Foo', 'newLocalOnlyKey': 'Not uploaded yet'};
      final downloaded = <String, dynamic>{'foo': 'Foo'};

      final result = ArbMergeUtil.mergeArb(local, downloaded);

      expect(result, {'foo': 'Foo', 'newLocalOnlyKey': 'Not uploaded yet'});
    });

    test('preserves local key order and appends new keys at the end', () {
      final local = <String, dynamic>{'a': '1', 'b': '2'};
      final downloaded = <String, dynamic>{'b': '2-updated', 'c': '3'};

      final result = ArbMergeUtil.mergeArb(local, downloaded);

      expect(result.keys.toList(), ['a', 'b', 'c']);
      expect(result['b'], '2-updated');
    });

    test('returns the downloaded map as-is when local is empty', () {
      final downloaded = <String, dynamic>{'foo': 'Foo'};

      final result = ArbMergeUtil.mergeArb(<String, dynamic>{}, downloaded);

      expect(result, {'foo': 'Foo'});
    });

    test('keeps all local entries when downloaded is empty', () {
      final local = <String, dynamic>{'foo': 'Foo'};

      final result = ArbMergeUtil.mergeArb(local, <String, dynamic>{});

      expect(result, {'foo': 'Foo'});
    });

    test('merges nested @key metadata objects like any other entry', () {
      final local = <String, dynamic>{
        'foo': 'Old Foo',
        '@foo': {'description': 'old description'},
      };
      final downloaded = <String, dynamic>{
        'foo': 'New Foo',
        '@foo': {'description': 'new description'},
      };

      final result = ArbMergeUtil.mergeArb(local, downloaded);

      expect(result['foo'], 'New Foo');
      expect(result['@foo'], {'description': 'new description'});
    });
  });
}
