bool isValidCard(String cardNumber) {
  final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 13 || digits.length > 19) return false;

  int sum = 0;
  bool doubleIt = false;
  for (int i = digits.length - 1; i >= 0; i--) {
    int d = digits.codeUnitAt(i) - 0x30;
    if (doubleIt) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    doubleIt = !doubleIt;
  }
  return sum % 10 == 0;
}
