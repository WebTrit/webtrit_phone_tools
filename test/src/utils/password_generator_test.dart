import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/utils/password_generator.dart';

void main() {
  test('PasswordGenerator.random() generate random passwords', () {
    final password1 = PasswordGenerator.random();
    final password2 = PasswordGenerator.random();
    expect(password1, isNot(password2));
  });
}
