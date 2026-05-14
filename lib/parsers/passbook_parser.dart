import '../models/bank_details.dart';

BankDetails parsePassbook(String rawText) {
  final lines = _splitLines(rawText);
  final ifsc = _findIfsc(rawText);
  return BankDetails(
    accountHolderName: _findHolderName(lines),
    accountNumber: _findAccountNumber(lines, ifsc),
    ifscCode: ifsc,
  );
}

String? _findIfsc(String rawText) {
  final regex = RegExp(r'\b([A-Z]{4}0[A-Z0-9]{6})\b');
  final m1 = regex.firstMatch(rawText);
  if (m1 != null) return m1.group(1);
  final m2 = regex.firstMatch(rawText.toUpperCase());
  return m2?.group(1);
}

String? _findAccountNumber(List<String> lines, String? ifsc) {
  const keywords = [
    'A/C', 'A/C NO', 'AC NO', 'ACCOUNT', 'ACC NO', 'ACCT',
    'ACCOUNT NUMBER', 'ACCOUNT NO',
  ];

  final candidates = <_Candidate>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    for (final m in RegExp(r'\b\d{9,18}\b').allMatches(line)) {
      final num = m.group(0)!;
      int score = num.length;

      final context = [
        if (i > 0) lines[i - 1],
        line,
        if (i < lines.length - 1) lines[i + 1],
      ].join(' ').toUpperCase();
      if (keywords.any(context.contains)) score += 50;

      if (ifsc != null && ifsc.contains(num)) score -= 100;
      // Indian mobile numbers start with 6–9 and are exactly 10 digits.
      if (num.length == 10 && RegExp(r'^[6-9]').hasMatch(num)) score -= 30;

      candidates.add(_Candidate(num, score));
    }
  }

  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.score.compareTo(a.score));
  return candidates.first.value;
}

class _Candidate {
  final String value;
  final int score;
  _Candidate(this.value, this.score);
}

String? _findHolderName(List<String> lines) {
  const nameKeywords = ['NAME', 'A/C HOLDER', 'ACCOUNT HOLDER', 'HOLDER'];
  const banned = {
    'BANK', 'BRANCH', 'IFSC', 'ACCOUNT', 'PASSBOOK', 'STATEMENT',
    'SAVINGS', 'CURRENT', 'CUSTOMER', 'ID', 'NO', 'NUMBER',
    'ADDRESS', 'PHONE', 'MOBILE', 'EMAIL', 'DATE', 'BALANCE',
    'OPENING', 'CLOSING', 'INDIA', 'LIMITED', 'LTD', 'PVT',
    'MICR', 'CODE', 'TYPE', 'NOMINEE', 'REGISTERED',
  };

  for (final raw in lines) {
    final upper = raw.toUpperCase();
    for (final kw in nameKeywords) {
      final idx = upper.indexOf(kw);
      if (idx == -1) continue;

      var after = raw.substring(idx + kw.length).trim();
      after = after.replaceAll(RegExp(r'^[:\-\.\s]+'), '');
      final digit = RegExp(r'\d').firstMatch(after);
      if (digit != null) after = after.substring(0, digit.start);
      after = after.trim();

      if (_looksLikeName(after, banned)) return after.toUpperCase();
    }
  }

  for (final raw in lines) {
    final line = raw.trim();
    if (_looksLikeName(line, banned, requireUpper: true)) {
      return line.toUpperCase();
    }
  }

  return null;
}

bool _looksLikeName(String s, Set<String> banned, {bool requireUpper = false}) {
  if (s.length < 4) return false;
  if (RegExp(r'\d').hasMatch(s)) return false;
  if (!RegExp(r"^[A-Za-z .\-']+$").hasMatch(s)) return false;

  final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length < 2) return false;

  final upperWords = words.map((w) => w.toUpperCase()).toSet();
  if (upperWords.intersection(banned).isNotEmpty) return false;

  if (requireUpper) {
    final letters = s.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return false;
    final upperCount =
        letters.split('').where((c) => c == c.toUpperCase()).length;
    if (upperCount / letters.length < 0.8) return false;
  }

  return true;
}

List<String> _splitLines(String text) =>
    text.split(RegExp(r'[\r\n]+')).where((l) => l.trim().isNotEmpty).toList();
