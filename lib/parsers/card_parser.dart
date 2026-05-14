import '../models/card_details.dart';
import 'luhn.dart';

CardDetails parseCard(String rawText) {
  final lines = _splitLines(rawText);
  return CardDetails(
    cardNumber: _findCardNumber(rawText),
    expiry: _findExpiry(rawText),
    holderName: _findHolderName(lines),
  );
}

String? _findCardNumber(String rawText) {
  final grouped = RegExp(r'(?:[0-9OIlSB]{3,6}[ \-]+){2,4}[0-9OIlSB]{3,6}');
  final solid = RegExp(r'[0-9OIlSB]{13,19}');

  final candidates = <String>[];
  void addFrom(Iterable<RegExpMatch> matches) {
    for (final m in matches) {
      final fixed = _fixOcrDigits(m.group(0)!).replaceAll(RegExp(r'\D'), '');
      if (fixed.length >= 13 && fixed.length <= 19) candidates.add(fixed);
    }
  }

  addFrom(grouped.allMatches(rawText));
  addFrom(solid.allMatches(rawText));

  if (candidates.isEmpty) return null;

  for (final c in candidates) {
    if (isValidCard(c)) return c;
  }

  // Nothing passed Luhn — still return the longest plausible candidate
  // so the UI can show it with a "Luhn failed" warning instead of nothing.
  candidates.sort((a, b) => b.length.compareTo(a.length));
  return candidates.first.length >= 15 ? candidates.first : null;
}

String _fixOcrDigits(String s) {
  return s
      .replaceAll('O', '0')
      .replaceAll('o', '0')
      .replaceAll('I', '1')
      .replaceAll('l', '1')
      .replaceAll('S', '5')
      .replaceAll('B', '8');
}

String? _findExpiry(String rawText) {
  final separated = RegExp(r'\b(0[1-9]|1[0-2])\s*[\/\-\s]\s*(\d{2}|\d{4})\b');
  for (final m in separated.allMatches(rawText)) {
    final mm = m.group(1)!;
    var yy = m.group(2)!;
    if (yy.length == 4) yy = yy.substring(2);
    return '$mm/$yy';
  }

  // Glued MMYY form — restrict the year window so random 4-digit groups
  // (CVV, last 4, branch code) don't get picked up.
  final glued = RegExp(r'\b(0[1-9]|1[0-2])(\d{2})\b');
  for (final m in glued.allMatches(rawText)) {
    final yy = int.parse(m.group(2)!);
    if (yy >= 20 && yy <= 40) return '${m.group(1)}/${m.group(2)}';
  }

  return null;
}

String? _findHolderName(List<String> lines) {
  const banned = {
    'VISA', 'MASTERCARD', 'MASTER', 'CARD', 'DEBIT', 'CREDIT',
    'BANK', 'PLATINUM', 'GOLD', 'SILVER', 'CLASSIC', 'BUSINESS',
    'VALID', 'THRU', 'FROM', 'EXPIRES', 'EXP', 'GOOD',
    'MEMBER', 'SINCE', 'AUTHORIZED', 'SIGNATURE',
    'RUPAY', 'AMEX', 'AMERICAN', 'EXPRESS', 'DISCOVER',
  };

  for (final raw in lines) {
    final line = raw.trim();
    if (line.length < 5) continue;
    if (RegExp(r'\d').hasMatch(line)) continue;
    if (!RegExp(r"^[A-Za-z .\-']+$").hasMatch(line)) continue;

    final words = line.split(RegExp(r'\s+'));
    if (words.length < 2) continue;

    final letters = line.replaceAll(RegExp(r'[^A-Za-z]'), '');
    final upperRatio =
        letters.split('').where((c) => c == c.toUpperCase()).length /
            letters.length;
    if (upperRatio < 0.8) continue;

    final upperWords = words.map((w) => w.toUpperCase()).toSet();
    if (upperWords.intersection(banned).isNotEmpty) continue;

    return line.toUpperCase();
  }

  return null;
}

List<String> _splitLines(String text) =>
    text.split(RegExp(r'[\r\n]+')).where((l) => l.trim().isNotEmpty).toList();
