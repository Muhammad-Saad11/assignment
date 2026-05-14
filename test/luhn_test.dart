import 'package:flutter_test/flutter_test.dart';
import 'package:assignment/parsers/luhn.dart';

void main() {
  group('isValidCard', () {
    test('accepts well-known valid card numbers', () {
      // These are the standard published test card numbers (not real cards).
      expect(isValidCard('4111111111111111'), isTrue); // Visa
      expect(isValidCard('5500000000000004'), isTrue); // MasterCard
      expect(isValidCard('340000000000009'), isTrue);  // Amex (15 digits)
      expect(isValidCard('6011000000000004'), isTrue); // Discover
    });

    test('accepts numbers with spaces and dashes', () {
      expect(isValidCard('4111 1111 1111 1111'), isTrue);
      expect(isValidCard('4111-1111-1111-1111'), isTrue);
    });

    test('rejects numbers that fail the Luhn check', () {
      expect(isValidCard('4111111111111112'), isFalse);
      expect(isValidCard('1234567812345678'), isFalse);
    });

    test('rejects numbers that are too short or too long', () {
      expect(isValidCard('411111'), isFalse);                    // 6 digits
      expect(isValidCard('41111111111111111111'), isFalse);      // 20 digits
    });

    test('rejects empty / non-numeric input', () {
      expect(isValidCard(''), isFalse);
      expect(isValidCard('abcdefghij'), isFalse);
    });
  });
}
