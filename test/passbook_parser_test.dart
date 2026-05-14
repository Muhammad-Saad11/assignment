import 'package:flutter_test/flutter_test.dart';
import 'package:assignment/parsers/passbook_parser.dart';

void main() {
  group('parsePassbook', () {
    test('extracts name, account number and IFSC from a clean scan', () {
      const raw = '''
STATE BANK OF INDIA
Branch: Andheri East
A/C Holder: JOHN DOE
A/C No: 123456789012
IFSC: SBIN0001234
''';
      final r = parsePassbook(raw);
      expect(r.accountHolderName, 'JOHN DOE');
      expect(r.accountNumber, '123456789012');
      expect(r.ifscCode, 'SBIN0001234');
    });

    test('picks the account number near the "account" keyword, '
        'not a random long number', () {
      // Mobile-shaped number and a customer ID appear before the real
      // account number — the parser should prefer the one near "A/C No".
      const raw = '''
Customer ID 987654321
Mobile: 9876543210
A/C No 111122223333
IFSC HDFC0009999
''';
      final r = parsePassbook(raw);
      expect(r.accountNumber, '111122223333');
    });

    test('detects IFSC anywhere in the text', () {
      const raw = 'random noise HDFC0001234 more noise';
      final r = parsePassbook(raw);
      expect(r.ifscCode, 'HDFC0001234');
    });

    test('returns null fields when nothing usable is found', () {
      final r = parsePassbook('hello world');
      expect(r.accountHolderName, isNull);
      expect(r.accountNumber, isNull);
      expect(r.ifscCode, isNull);
      expect(r.isEmpty, isTrue);
    });

    test('extracts name from a "Name:" labelled line', () {
      const raw = '''
PASSBOOK
Name: JANE SMITH
A/C No 555666777888
''';
      final r = parsePassbook(raw);
      expect(r.accountHolderName, 'JANE SMITH');
    });
  });
}
