import '../models/card_details.dart';
import 'luhn.dart';

/// Parse the raw OCR text of a credit / debit card.
///
/// The text we get from OCR is noisy: random ordering, broken spacing,
/// stray words like "VALID THRU", letters mistaken for digits, etc.
/// We do three independent passes — one per field — and combine the
/// results. Any field can be null if we couldn't find it.
CardDetails parseCard(String rawText) {
  final lines = _splitLines(rawText);

  return CardDetails(
    cardNumber: _findCardNumber(rawText),
    expiry: _findExpiry(rawText),
    holderName: _findHolderName(lines),
  );
}

// --------------------------------------------------------------------------
// Card number
// --------------------------------------------------------------------------

/// Look for the card number anywhere in the text.
///
/// Strategy:
///   - real-world card numbers are printed in one of two shapes:
///       a) several groups of 3–5 digits separated by spaces / dashes
///          (Visa / MC: 4-4-4-4, Amex: 4-6-5, 19-digit RuPay: 4-4-4-4-3)
///       b) a single solid run of 13–19 digits
///     We look for those shapes specifically — that way we don't
///     accidentally glue the expiry's "12 25" onto the end of a number.
///   - inside each candidate we allow the letters OCR most often
///     confuses with digits (O, I, l, S, B) and fix them up.
///   - return the first candidate that passes Luhn; if none does,
///     fall back to the longest plausible one so the UI can still
///     show something (the UI labels it as "Luhn check failed").
String? _findCardNumber(String rawText) {
  // a) groups separated by space/dash: "1234 5678 9012 3456"
  final groupedRegex =
      RegExp(r'(?:[0-9OIlSB]{3,6}[ \-]+){2,4}[0-9OIlSB]{3,6}');
  // b) one long run: "1234567890123456"
  final solidRegex = RegExp(r'[0-9OIlSB]{13,19}');

  final candidates = <String>[];
  void addFrom(Iterable<RegExpMatch> matches) {
    for (final m in matches) {
      final fixed = _fixOcrDigits(m.group(0)!).replaceAll(RegExp(r'\D'), '');
      if (fixed.length >= 13 && fixed.length <= 19) candidates.add(fixed);
    }
  }

  addFrom(groupedRegex.allMatches(rawText));
  addFrom(solidRegex.allMatches(rawText));

  if (candidates.isEmpty) return null;

  // Prefer the first one that's actually a valid card.
  for (final c in candidates) {
    if (isValidCard(c)) return c;
  }

  // Fallback: nothing validated — return the longest blob, but only if
  // it really looks like a card (avoids returning random phone numbers).
  candidates.sort((a, b) => b.length.compareTo(a.length));
  final longest = candidates.first;
  return longest.length >= 15 ? longest : null;
}

/// Replace the letters OCR most often confuses with digits, but only
/// inside a candidate that we already think is a card number blob.
String _fixOcrDigits(String s) {
  return s
      .replaceAll('O', '0')
      .replaceAll('o', '0')
      .replaceAll('I', '1')
      .replaceAll('l', '1')
      .replaceAll('S', '5')
      .replaceAll('B', '8');
}

// --------------------------------------------------------------------------
// Expiry
// --------------------------------------------------------------------------

/// Detect expiry in any of these formats:
///   MM/YY   MM-YY   MM/YYYY   MM YY   MMYY
///
/// We always normalise to "MM/YY" before returning. If the captured
/// month is not 01–12 we discard the match (avoids picking up the
/// "VALID FROM" date on some cards).
String? _findExpiry(String rawText) {
  // Try the explicit separator versions first — they're unambiguous.
  final separated = RegExp(r'\b(0[1-9]|1[0-2])\s*[\/\-\s]\s*(\d{2}|\d{4})\b');
  for (final m in separated.allMatches(rawText)) {
    final mm = m.group(1)!;
    var yy = m.group(2)!;
    if (yy.length == 4) yy = yy.substring(2);
    return '$mm/$yy';
  }

  // Glued 4-digit form "MMYY". This one is risky — lots of 4-digit
  // groups in random text could match — so we keep it strict and look
  // for a *standalone* 4-digit number where MM is 01–12.
  final glued = RegExp(r'\b(0[1-9]|1[0-2])(\d{2})\b');
  for (final m in glued.allMatches(rawText)) {
    final mm = m.group(1)!;
    final yy = m.group(2)!;
    // Reasonable year window: 20–40 (covers 2020–2040 expiry dates).
    final yearInt = int.parse(yy);
    if (yearInt >= 20 && yearInt <= 40) {
      return '$mm/$yy';
    }
  }

  return null;
}

// --------------------------------------------------------------------------
// Holder name
// --------------------------------------------------------------------------

/// A cardholder name on a physical card is almost always:
///   - on its own line
///   - upper-case letters and spaces (sometimes a "." or "-")
///   - 2+ words
///   - no digits
///
/// We also skip well-known banner words like "VISA", "MASTERCARD",
/// "VALID THRU", "BANK" etc. — those lines look name-shaped but aren't.
String? _findHolderName(List<String> lines) {
  const bannedWords = {
    'VISA', 'MASTERCARD', 'MASTER', 'CARD', 'DEBIT', 'CREDIT',
    'BANK', 'PLATINUM', 'GOLD', 'SILVER', 'CLASSIC', 'BUSINESS',
    'VALID', 'THRU', 'FROM', 'EXPIRES', 'EXP', 'GOOD',
    'MEMBER', 'SINCE', 'AUTHORIZED', 'SIGNATURE',
    'RUPAY', 'AMEX', 'AMERICAN', 'EXPRESS', 'DISCOVER',
  };

  for (final raw in lines) {
    final line = raw.trim();
    if (line.length < 5) continue;            // too short
    if (RegExp(r'\d').hasMatch(line)) continue; // names have no digits

    // Only allow A-Z, space, dot, hyphen, apostrophe.
    if (!RegExp(r"^[A-Za-z .\-']+$").hasMatch(line)) continue;

    final words = line.split(RegExp(r'\s+'));
    if (words.length < 2) continue;           // need at least first + last

    // Must be mostly upper-case (cards are printed in caps).
    final upperRatio = line
            .replaceAll(RegExp(r'[^A-Za-z]'), '')
            .split('')
            .where((c) => c == c.toUpperCase())
            .length /
        line.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
    if (upperRatio < 0.8) continue;

    // Skip banner / marketing words.
    final upperWords = words.map((w) => w.toUpperCase()).toSet();
    if (upperWords.intersection(bannedWords).isNotEmpty) continue;

    return line.toUpperCase();
  }

  return null;
}

// --------------------------------------------------------------------------
// helpers
// --------------------------------------------------------------------------

List<String> _splitLines(String text) =>
    text.split(RegExp(r'[\r\n]+')).where((l) => l.trim().isNotEmpty).toList();
