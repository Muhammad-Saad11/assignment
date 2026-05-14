class CardDetails {
  final String? cardNumber;
  final String? expiry;
  final String? holderName;

  const CardDetails({
    this.cardNumber,
    this.expiry,
    this.holderName,
  });

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
