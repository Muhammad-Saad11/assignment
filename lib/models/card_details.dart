/// Result of parsing a credit/debit card image.
///
/// Every field is nullable on purpose — OCR can miss any of them, and we
/// want the UI to be able to show partial results instead of failing hard.
class CardDetails {
  final String? cardNumber;   // digits only, e.g. "4111111111111111"
  final String? expiry;       // normalised "MM/YY"
  final String? holderName;   // upper-cased name as printed, or null

  const CardDetails({
    this.cardNumber,
    this.expiry,
    this.holderName,
  });

  /// Mask everything except the last 4 digits: "XXXX XXXX XXXX 1234".
  String get maskedCardNumber {
    final n = cardNumber;
    if (n == null || n.length < 4) return '----';
    final last4 = n.substring(n.length - 4);
    final hiddenGroups = ((n.length - 4) / 4).ceil();
    final masked = List.filled(hiddenGroups, 'XXXX').join(' ');
    return '$masked $last4'.trim();
  }

  bool get isEmpty =>
      cardNumber == null && expiry == null && holderName == null;

  @override
  String toString() =>
      'CardDetails(number: $cardNumber, expiry: $expiry, name: $holderName)';
}
