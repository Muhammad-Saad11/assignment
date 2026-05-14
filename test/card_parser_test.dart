import 'package:flutter_test/flutter_test.dart';
import 'package:assignment/parsers/card_parser.dart';

void main() {
  group('parseCard', () {
    test('clean scan', () {
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

    test('inconsistent spacing', () {
      const raw = 'Card: 4111  1111-1111 1111 EXP 09/27 JANE SMITH';
      final r = parseCard(raw);
      expect(r.cardNumber, '4111111111111111');
      expect(r.expiry, '09/27');
    });

    test('glued MMYY expiry', () {
      const raw = '4111111111111111 0828 MIKE ROSS';
      expect(parseCard(raw).expiry, '08/28');
    });

    test('MM-YY expiry', () {
      expect(parseCard('4111 1111 1111 1111 03-26').expiry, '03/26');
    });

    test('OCR misreads O and I', () {
      const raw = '4III IIII IIII IIII 12/25';
      expect(parseCard(raw).cardNumber, '4111111111111111');
    });

    test('nothing usable', () {
      final r = parseCard('totally unrelated text with no numbers');
      expect(r.isEmpty, isTrue);
    });

    test('skips banner words', () {
      const raw = '''
MASTERCARD
5500 0000 0000 0004
12/25
JOHN DOE
''';
      expect(parseCard(raw).holderName, 'JOHN DOE');
    });

    test('mask keeps last 4', () {
      final r = parseCard('4111 1111 1111 1111 12/25');
      expect(r.maskedCardNumber, 'XXXX XXXX XXXX 1111');
    });
  });
}
