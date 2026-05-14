class BankDetails {
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;

  const BankDetails({
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
  });

  bool get isEmpty =>
      accountHolderName == null && accountNumber == null && ifscCode == null;

  @override
  String toString() =>
      'BankDetails(name: $accountHolderName, acc: $accountNumber, ifsc: $ifscCode)';
}
