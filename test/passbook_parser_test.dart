import 'package:flutter_test/flutter_test.dart';
import 'package:assignment/parsers/passbook_parser.dart';

void main() {
  group('parsePassbook', () {
    test('clean scan', () {
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

    test('picks account number near keyword', () {
      const raw = '''
Customer ID 987654321
Mobile: 9876543210
A/C No 111122223333
IFSC HDFC0009999
''';
      expect(parsePassbook(raw).accountNumber, '111122223333');
    });

    test('IFSC anywhere in text', () {
      expect(parsePassbook('random noise HDFC0001234 more noise').ifscCode,
          'HDFC0001234');
    });

    test('nothing usable', () {
      expect(parsePassbook('hello world').isEmpty, isTrue);
    });

    test('Name: labelled line', () {
      const raw = '''
PASSBOOK
Name: JANE SMITH
A/C No 555666777888
''';
      expect(parsePassbook(raw).accountHolderName, 'JANE SMITH');
    });
  });
}
