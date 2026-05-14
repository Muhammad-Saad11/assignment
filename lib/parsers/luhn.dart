/// Validate a card number using the Luhn (mod-10) algorithm.
///
/// Step by step:
///   1. Strip out everything that isn't a digit (so "4111-1111 1111 1111"
///      works the same as "4111111111111111").
///   2. Reject anything outside the realistic 13–19 digit range —
///      that range covers Visa / MasterCard / Amex / Discover / RuPay.
///   3. Walk the digits from RIGHT to LEFT. Every second digit gets
///      doubled. If the doubled value is two digits (>= 10) we add the
///      two digits together (which is the same as subtracting 9).
///   4. The card is valid iff the final sum is divisible by 10.
bool isValidCard(String cardNumber) {
  // 1. keep digits only
  final digits = cardNumber.replaceAll(RegExp(r'\D'), '');

  // 2. sanity check on length
  if (digits.length < 13 || digits.length > 19) return false;

  // 3. Luhn sum
  int sum = 0;
  bool shouldDouble = false; // alternates starting from the rightmost digit
  for (int i = digits.length - 1; i >= 0; i--) {
    int d = digits.codeUnitAt(i) - 0x30; // '0' is 0x30, faster than int.parse
    if (shouldDouble) {
      d *= 2;
      if (d > 9) d -= 9; // same as summing the two digits
    }
    sum += d;
    shouldDouble = !shouldDouble;
  }

  // 4. valid if mod 10 == 0
  return sum % 10 == 0;
}
