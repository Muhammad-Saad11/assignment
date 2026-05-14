import '../models/bank_details.dart';

/// Parse the raw OCR text of a bank passbook / cheque / statement.
///
/// Like the card parser, every field is independent and any of them
/// can come back null. The order we look in matters because each pass
/// uses different heuristics:
///
///   1. IFSC — strict regex, very high confidence when it hits.
///   2. Account number — context first (keywords nearby), then fallback
///      to the longest standalone number that isn't the IFSC.
///   3. Name — line with all letters, near a "name" keyword if possible.
BankDetails parsePassbook(String rawText) {
  final lines = _splitLines(rawText);

  final ifsc = _findIfsc(rawText);
  final accountNumber = _findAccountNumber(lines, ifsc);
  final name = _findHolderName(lines);

  return BankDetails(
    accountHolderName: name,
    accountNumber: accountNumber,
    ifscCode: ifsc,
  );
}

// --------------------------------------------------------------------------
// IFSC
// --------------------------------------------------------------------------

/// Indian IFSC code: 4 letters (bank) + '0' + 6 alphanumeric (branch).
/// Example: HDFC0001234, SBIN0005678.
String? _findIfsc(String rawText) {
  // Look for the pattern anywhere in the text. We allow surrounding
  // word boundaries so we don't catch substrings of longer junk.
  final regex = RegExp(r'\b([A-Z]{4}0[A-Z0-9]{6})\b');

  // Try the text as-is first (most cards / passbooks are upper-case).
  final m1 = regex.firstMatch(rawText);
  if (m1 != null) return m1.group(1);

  // Fallback: try upper-casing — handles passbooks where OCR returned
  // mixed case for the IFSC.
  final m2 = regex.firstMatch(rawText.toUpperCase());
  return m2?.group(1);
}

// --------------------------------------------------------------------------
// Account number
// --------------------------------------------------------------------------

/// An account number in India is typically 9–18 digits. There are
/// usually MANY numbers on a passbook (customer ID, branch code, mobile
/// number, etc.), so we score candidates and pick the best one.
///
/// Scoring rules (higher is better):
///   +5 if the same line, or the previous/next line, contains a keyword
///      like "A/C", "Account", "ACCOUNT NO", "AC NO".
///   +1 per digit of length (longer numbers are more likely the account).
///   -10 if it equals the digits embedded inside the IFSC (shouldn't
///       happen but cheap to guard against).
///   -5 if it looks like a phone number (10 digits starting with 6-9 in
///       India — could still be wrong, but it's a useful tiebreaker).
String? _findAccountNumber(List<String> lines, String? ifsc) {
  const keywords = [
    'A/C', 'A/C NO', 'AC NO', 'ACCOUNT', 'ACC NO', 'ACCT',
    'ACCOUNT NUMBER', 'ACCOUNT NO',
  ];

  final candidates = <_Candidate>[];

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Pull every digit run of length 9–18 from this line.
    final numberRegex = RegExp(r'\b\d{9,18}\b');
    for (final m in numberRegex.allMatches(line)) {
      final num = m.group(0)!;
      int score = num.length; // base score = length

      // Bonus if this or an adjacent line mentions "account".
      final context = [
        if (i > 0) lines[i - 1],
        line,
        if (i < lines.length - 1) lines[i + 1],
      ].join(' ').toUpperCase();
      if (keywords.any(context.contains)) score += 50;

      // Penalty if it's the IFSC's embedded digits (defensive).
      if (ifsc != null && ifsc.contains(num)) score -= 100;

      // Penalty for plausible Indian mobile numbers.
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

// --------------------------------------------------------------------------
// Holder name
// --------------------------------------------------------------------------

/// Find the account holder's name in noisy text.
///
/// Two strategies, in order:
///   1. Look for a line containing a "name" keyword and pull the
///      letters that follow it (handles "Name: MR JOHN DOE").
///   2. Fall back to the first line that looks like a person's name
///      (letters only, 2+ words, not a banking term).
String? _findHolderName(List<String> lines) {
  const nameKeywords = ['NAME', 'A/C HOLDER', 'ACCOUNT HOLDER', 'HOLDER'];
  const bannedWords = {
    'BANK', 'BRANCH', 'IFSC', 'ACCOUNT', 'PASSBOOK', 'STATEMENT',
    'SAVINGS', 'CURRENT', 'CUSTOMER', 'ID', 'NO', 'NUMBER',
    'ADDRESS', 'PHONE', 'MOBILE', 'EMAIL', 'DATE', 'BALANCE',
    'OPENING', 'CLOSING', 'INDIA', 'LIMITED', 'LTD', 'PVT',
    'MICR', 'CODE', 'TYPE', 'NOMINEE', 'REGISTERED',
  };

  // Strategy 1 — "Name: SOMETHING" or "NAME SOMETHING" on the same line.
  for (final raw in lines) {
    final upper = raw.toUpperCase();
    for (final kw in nameKeywords) {
      final idx = upper.indexOf(kw);
      if (idx == -1) continue;
      // Take whatever comes after the keyword.
      var after = raw.substring(idx + kw.length).trim();
      // Strip a leading ":" / "-" / "." that often follows the label.
      after = after.replaceAll(RegExp(r'^[:\-\.\s]+'), '');
      // Cut off at the first digit (so "Name: John 12345" -> "John").
      final digitMatch = RegExp(r'\d').firstMatch(after);
      if (digitMatch != null) after = after.substring(0, digitMatch.start);
      after = after.trim();

      if (_looksLikeName(after, bannedWords)) return after.toUpperCase();
    }
  }

  // Strategy 2 — first line that simply looks like a name.
  // For the fallback we additionally require the line to be mostly
  // upper-case. Bank documents print the holder name in caps, and the
  // extra check protects against picking up random sentence text
  // (e.g. "hello world") as a name.
  for (final raw in lines) {
    final line = raw.trim();
    if (_looksLikeName(line, bannedWords, requireUpper: true)) {
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

// --------------------------------------------------------------------------

List<String> _splitLines(String text) =>
    text.split(RegExp(r'[\r\n]+')).where((l) => l.trim().isNotEmpty).toList();
