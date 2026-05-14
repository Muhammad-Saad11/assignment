# Card & Passbook Scanner

Flutter app that scans credit/debit cards and bank passbooks using on-device
OCR (ML Kit) and extracts the structured fields with hand-written parsers.

## Features

**Card Scanner**
- Camera or gallery
- Extracts card number, expiry (MM/YY, MM-YY, MMYY), holder name
- Luhn-validates the number, shows pass/fail
- Masks the number as `XXXX XXXX XXXX 1234`

**Passbook Scanner**
- Camera or gallery
- Extracts account holder name, account number, IFSC code
- Picks the right account number when the page has multiple long numbers

Both screens show the image preview, parsed fields, and an error state when
OCR finds nothing or the parsers can't make sense of the text.

## How to run

```bash
flutter pub get
flutter run        # connect an Android device / emulator (API 21+)
flutter test       # runs the parser + Luhn tests
```

First scan downloads the ML Kit model (a few MB, one-time). After that it
runs fully offline.

## Project layout

```
lib/
  main.dart
  models/        CardDetails, BankDetails
  parsers/       luhn.dart, card_parser.dart, passbook_parser.dart   (all manual)
  services/      ocr_service.dart      (ML Kit wrapper)
  screens/       home, card_scanner, passbook_scanner
test/
  luhn_test.dart, card_parser_test.dart, passbook_parser_test.dart
```

## Libraries used

| Library                          | Why                                |
| -------------------------------- | ---------------------------------- |
| `google_mlkit_text_recognition`  | OCR engine                         |
| `image_picker`                   | Camera + gallery                   |
| `flutter_test`                   | Unit tests                         |
| `flutter_lints`                  | Lint rules                         |

No parsing library is used. Luhn, the card parser and the passbook parser are
plain Dart.

## How the parsers work

**Luhn.** Strip non-digits, reject if length isn't 13–19, walk right-to-left
doubling every second digit (subtract 9 if it goes above 9), accept when the
sum is a multiple of 10.

**Card parser.** Three independent passes:
1. Card number — match either (a) 3–5 groups of 3–6 digits separated by
   spaces/dashes, or (b) a single 13–19 digit run. OCR letter→digit fixes
   (O→0, I/l→1, S→5, B→8) are applied only inside these candidates so the
   holder name isn't mangled. Returns the first candidate that passes Luhn;
   falls back to the longest plausible one otherwise.
2. Expiry — try `MM/YY`, `MM-YY`, `MM YY` with month 01–12 first; fall back
   to glued `MMYY` with a 20–40 year window.
3. Holder name — line of letters only, 2+ words, mostly upper-case, not one
   of the banner words (`VISA`, `VALID THRU`, `BANK`, …).

**Passbook parser.**
1. IFSC — regex `[A-Z]{4}0[A-Z0-9]{6}`.
2. Account number — collect every 9–18 digit run, score each: bigger length
   = better, +50 if an adjacent line contains `A/C` / `ACCOUNT` / `AC NO`,
   −30 if the number looks like an Indian mobile (10 digits starting 6–9),
   −100 if it appears inside the IFSC. Highest score wins.
3. Holder name — first try `Name:` / `A/C Holder:` style labels, then fall
   back to the first line that's name-shaped and mostly upper-case.

## Edge cases handled

- Inconsistent spacing / dashes in the card number
- OCR misreads O↔0, I/l↔1, S↔5, B↔8 (only inside the card-number candidate)
- Multiple numbers in passbook text — scoring + keyword proximity
- Missing fields — every model field is nullable, UI shows "Not found"
- Blurry / empty OCR result — handled at screen level with an error box
- Duplicate scans — state resets on each pick
- Luhn fails — number is still displayed with a warning so the user can retry

## Tests

`flutter test` runs 18 cases covering Luhn correctness, card parsing
(spacing, expiry formats, OCR fixes, banner-word skipping, masking, empty
input), and passbook parsing (account-number scoring, IFSC detection,
labelled-name extraction, empty input).

## Assumptions

- Latin script only (ML Kit configured for Latin)
- Indian banking conventions for IFSC + passbook keywords
- Card lengths 13–19 (Visa / MasterCard / Amex / Discover / RuPay)
- Year window 20–40 for the glued `MMYY` fallback — wider windows produce
  too many false positives on random 4-digit groups
- Last-4 masking is the standard PCI display pattern

## What was skipped, and why

- **iOS** — optional in the brief; Dart code is iOS-clean but `Info.plist`
  permissions aren't wired up.
- **Custom camera overlay / auto-capture** — `image_picker` is enough for
  the assignment. A real product would use the `camera` plugin with a
  card-shaped overlay.
- **Bank-name / card-brand detection** — not asked for, would be a 5-line
  addition.
- **Persistence / scan history** — out of scope.
- **Widget tests** — brief asks for "1 test per algorithm"; parser/Luhn
  tests are there. Skipped widget tests to spend more time on parser
  robustness (40% of the grade).

## Improvements for production

- `camera` plugin with a card-shaped overlay and auto-capture
- Frame averaging — run OCR on several frames, vote on the digits
- Use ML Kit's per-element confidence scores to drive retries
- Per-country / per-language passbook keyword lists
- Telemetry on parser failures to drive improvements
