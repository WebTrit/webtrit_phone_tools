import 'dart:math';

const _lowerCaseLetters = 'abcdefghijklmnopqrstuvwxyz';
const _upperCaseLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _numbers = '0123456789';
const _special = r'@#=+!£$%&?[](){}';

class PasswordGenerator {
  PasswordGenerator._();

  static String random({
    bool letters = true,
    bool uppercase = false,
    bool numbers = false,
    bool specialChar = false,
    int passwordLength = 16,
  }) {
    if (letters == false && uppercase == false && specialChar == false && numbers == false) {
      throw ArgumentError();
    }
    final allowedCharsBuffer = StringBuffer();
    if (letters) {
      allowedCharsBuffer.write(_lowerCaseLetters);
    }
    if (uppercase) {
      allowedCharsBuffer.write(_upperCaseLetters);
    }
    if (numbers) {
      allowedCharsBuffer.write(_numbers);
    }
    if (specialChar) {
      allowedCharsBuffer.write(_special);
    }

    final allowedChars = allowedCharsBuffer.toString();
    final randomGenerator = Random.secure();

    final resultBuffer = StringBuffer();
    for (var i = 0; i < passwordLength; i++) {
      final randomIndex = randomGenerator.nextInt(allowedChars.length);
      final randomChar = allowedChars[randomIndex];
      resultBuffer.write(randomChar);
    }

    return resultBuffer.toString();
  }
}
