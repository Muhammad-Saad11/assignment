import 'package:flutter_test/flutter_test.dart';
import 'package:assignment/parsers/card_parser.dart';

void main() {
  group('parseCard', () {
    test('extracts number, expiry and name from a clean scan', () {
      const raw = '''
VISA
4111 1111 1111 1111
VALID THRU 12/25
JOHN DOE
''';
      final r = parseCard(raw);
      expect(r.cardNumber, '4111111111111111');
      expect(r.expiry, '12/25');
      expect(r.holderName, 'JOHN DOE');
    });

    test('handles inconsistent spacing in the card number', () {
      const raw = 'Card: 4111  1111-1111 1111 EXP 09/27 JANE SMITH';
      final r = parseCard(raw);
      expect(r.cardNumber, '4111111111111111');
      expect(r.expiry, '09/27');
    });

    test('parses MMYY (no separator) expiry', () {
      const raw = '4111111111111111 0828 MIKE ROSS';
      final r = parseCard(raw);
      expect(r.expiry, '08/28');
    });

    test('parses MM-YY expiry', () {
      const raw = '4111 1111 1111 1111 03-26';
      final r = parseCard(raw);
      expect(r.expiry, '03/26');
    });

    test('fixes common OCR misreads (O -> 0, I -> 1)', () {
      // The first three groups have OCR errors: O instead of 0, I instead of 1.
      const raw = '4III IIII IIII IIII 12/25';
      final r = parseCard(raw);
      expect(r.cardNumber, '4111111111111111');
    });

    test('returns null fields when nothing usable is found', () {
      final r = parseCard('totally unrelated text with no numbers');
      expect(r.cardNumber, isNull);
      expect(r.expiry, isNull);
      expect(r.holderName, isNull);
      expect(r.isEmpty, isTrue);
    });

    test('skips banner words like VISA and MASTERCARD as holder name', () {
      const raw = '''
MASTERCARD
5500 0000 0000 0004
12/25
JOHN DOE
''';
      final r = parseCard(raw);
      expect(r.holderName, 'JOHN DOE');
    });

    test('mask hides everything except the last 4 digits', () {
      final r = parseCard('4111 1111 1111 1111 12/25');
      expect(r.maskedCardNumber, 'XXXX XXXX XXXX 1111');
    });
  });
}
