import 'package:flutter_test/flutter_test.dart';
import 'package:assignment/parsers/luhn.dart';

void main() {
  group('isValidCard', () {
    test('accepts valid card numbers', () {
      expect(isValidCard('4111111111111111'), isTrue);
      expect(isValidCard('5500000000000004'), isTrue);
      expect(isValidCard('340000000000009'), isTrue);
      expect(isValidCard('6011000000000004'), isTrue);
    });

    test('ignores spaces and dashes', () {
      expect(isValidCard('4111 1111 1111 1111'), isTrue);
      expect(isValidCard('4111-1111-1111-1111'), isTrue);
    });

    test('rejects invalid checksums', () {
      expect(isValidCard('4111111111111112'), isFalse);
      expect(isValidCard('1234567812345678'), isFalse);
    });

    test('rejects bad lengths', () {
      expect(isValidCard('411111'), isFalse);
      expect(isValidCard('41111111111111111111'), isFalse);
    });

    test('rejects empty / non-numeric', () {
      expect(isValidCard(''), isFalse);
      expect(isValidCard('abcdefghij'), isFalse);
    });
  });
}
