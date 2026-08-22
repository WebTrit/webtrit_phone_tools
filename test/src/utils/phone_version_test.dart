import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/utils/phone_version.dart';

void main() {
  late Directory checkout;

  setUp(() {
    checkout = Directory.systemTemp.createTempSync('phone_version_test_');
  });

  tearDown(() => checkout.deleteSync(recursive: true));

  void writePubspec(String content) {
    File(p.join(checkout.path, 'pubspec.yaml')).writeAsStringSync(content);
  }

  test('reads app_version and drops the build number', () {
    writePubspec('''
name: webtrit_phone
version: 0.0.0+0000000
app_version: 1.16.5+3
''');

    expect(readPhoneVersion(checkout.path), '1.16.5');
  });

  test('does not mistake the standard version field for the phone version', () {
    writePubspec('''
name: webtrit_phone
version: 1.2.3+4
''');

    expect(readPhoneVersion(checkout.path), isNull);
  });

  test('reads nothing when app_version is empty', () {
    writePubspec('''
name: webtrit_phone
app_version: ""
''');

    expect(readPhoneVersion(checkout.path), isNull);
  });

  test('reads nothing from a pubspec that cannot be parsed', () {
    writePubspec('name: webtrit_phone\n  app_version: "1.16.5"\n\t- broken\n');

    expect(readPhoneVersion(checkout.path), isNull);
  });

  test('reads nothing from a pubspec that is not a mapping', () {
    writePubspec('- webtrit_phone\n- 1.16.5\n');

    expect(readPhoneVersion(checkout.path), isNull);
  });

  test('reads nothing when the directory does not exist', () {
    expect(readPhoneVersion(p.join(checkout.path, 'no-such-checkout')), isNull);
  });

  test('reads nothing when the checkout has no pubspec', () {
    expect(readPhoneVersion(checkout.path), isNull);
  });
}
