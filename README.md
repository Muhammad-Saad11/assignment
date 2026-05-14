# Card & Passbook Scanner

A Flutter app that scans **credit / debit cards** and **bank passbooks** using
on-device OCR (ML Kit) and extracts structured data with **manually written
parsers** — no parsing libraries.

Built as the technical assignment for a Mid-Level Flutter Developer role.

---

## Features

### 1. Card Scanner
- Open the camera (or pick from gallery) and capture a card.
- Extracts:
  - Card Number
  - Expiry Date (MM/YY, MM-YY, MMYY all supported)
  - Card Holder Name (when present)
- Validates the number with the **Luhn algorithm** and shows a pass/fail badge.
- Card number is **masked** in the UI as `XXXX XXXX XXXX 1234`.

### 2. Passbook / Bank Document Scanner
- Camera or gallery upload.
- Extracts:
  - Account Holder Name
  - Account Number (picks the right one when many numbers are present)
  - IFSC Code

Each screen shows the captured image preview, the parsed fields, and a clear
error state when OCR finds nothing or the parsers can't make sense of the text.

---

## Project structure

```
lib/
├── main.dart                              # app entry, navigates to HomeScreen
├── models/
│   ├── card_details.dart                  # CardDetails + masking helper
│   └── bank_details.dart                  # BankDetails
├── parsers/                               # ── all manual, no libraries ──
│   ├── luhn.dart                          # bool isValidCard(String)
│   ├── card_parser.dart                   # CardDetails parseCard(String)
│   └── passbook_parser.dart               # BankDetails parsePassbook(String)
├── services/
│   └── ocr_service.dart                   # thin wrapper around ML Kit
└── screens/
    ├── home_screen.dart                   # two-button menu
    ├── card_scanner_screen.dart
    └── passbook_scanner_screen.dart

test/
├── luhn_test.dart
├── card_parser_test.dart
└── passbook_parser_test.dart
```





On first scan, ML Kit will download its text-recognition model (one-time, a
few MB). Subsequent scans are fully offline.

---
| Library                          | Why                                              |
| -------------------------------- | ------------------------------------------------ |
| `google_mlkit_text_recognition`  | OCR engine (allowed by the assignment).          |
| `image_picker`                   | Camera + gallery in one simple API.              |
| `flutter_test`                   | Unit tests.                                      |
| `flutter_lints`                  | Linting (default Flutter rule set).              |

**No parsing library is used.** The Luhn check, card parser, and passbook
parser are written by hand in plain Dart.

---

## How the parsers work (short version)

### Luhn (`lib/parsers/luhn.dart`)
Strip non-digits → reject if length isn't 13–19 → walk the digits right-to-left,
doubling every second digit (subtract 9 if it goes above 9) → sum must be a
multiple of 10.

### Card parser (`lib/parsers/card_parser.dart`)
Three independent passes on the OCR text:
1. **Card number** — look for either (a) 3–5 groups of 3–6 digits separated by
   spaces/dashes, or (b) a single 13–19 digit run. OCR letter→digit fixes
   (O→0, I/l→1, S→5, B→8) are applied **only inside these candidates** so the
   holder name isn't mangled. Prefer the first candidate that passes Luhn.
2. **Expiry** — try `MM/YY`, `MM-YY`, `MM YY` first (strict month 01–12),
   then fall back to glued `MMYY` (with a 2020–2040 year window so we don't
   misfire on random 4-digit groups).
3. **Holder name** — line of letters only, 2+ words, mostly upper-case, not
   one of the banner words like `VISA`, `VALID THRU`, `BANK`, etc.

### Passbook parser (`lib/parsers/passbook_parser.dart`)
1. **IFSC** — strict regex `[A-Z]{4}0[A-Z0-9]{6}`. Very high signal when it
   hits.
2. **Account number** — gather every 9–18 digit run and score each one. Big
   bonus if the same line or an adjacent line mentions `A/C` / `ACCOUNT` /
   `AC NO`. Penalty if it looks like an Indian mobile number. Highest score
   wins.
3. **Holder name** — first try `Name: …` / `A/C Holder: …` style labels;
   fall back to the first line that's clearly name-shaped (letters only,
   2+ words, mostly upper-case).

---

## Edge cases handled

- **Inconsistent spacing / dashes** in the card number (`4111 1111 1111 1111`,
  `4111-1111-1111-1111`, `4111111111111111`).
- **OCR misreads** O↔0, I/l↔1, S↔5, B↔8 — corrected only inside the
  card-number candidate so the rest of the text stays intact.
- **Multiple numbers in passbook text** — the account-number scorer prefers
  numbers near `A/C` keywords and demotes phone-shaped numbers.
- **Missing fields** — every field on `CardDetails` / `BankDetails` is
  nullable; the UI shows "Not found" for missing ones rather than crashing.
- **Blurry / empty OCR result** — handled at the screen level with a friendly
  "No text could be read" error.
- **Duplicate scans** — each scan resets state before running, so the UI
  always reflects the latest image.
- **Luhn failure** — the UI still shows the extracted (likely-misread) number
  with a warning badge, so the user can retry.

---

## Tests

`flutter test` runs **18 unit tests** covering:
- **Luhn:** valid Visa / MasterCard / Amex / Discover numbers, spacing /
  dashes, invalid checksums, wrong lengths, non-numeric input.
- **Card parser:** clean scans, inconsistent spacing, all three expiry
  formats, OCR letter substitutions, banner-word skipping, masking, empty
  input.
- **Passbook parser:** clean scans, account-number scoring with multiple
  candidates, IFSC detection, labelled-name extraction, empty input.

```bash
flutter test
# Expected: All tests passed!
```

---

## Assumptions

- **Latin script only** — the ML Kit recognizer is configured for Latin.
  Adding Devanagari / Tamil / etc. is a one-line change in `OcrService` but
  wasn't required by the brief.
- **Indian banking conventions** — the IFSC pattern is India-specific, and
  the passbook parser's keyword list (`A/C`, `IFSC`, etc.) is tuned for
  Indian passbooks. Card parsing itself is internationally neutral.
- **Manually validated card lengths 13–19** — covers Visa (13/16/19),
  MasterCard (16), Amex (15), Discover (16), RuPay (16/19).
- **Expiry year window 2020–2040** for the glued `MMYY` fallback — wider
  windows produce too many false positives on random 4-digit groups.
- **Card number masking always keeps the last 4 digits** — standard PCI
  display pattern.

---

## What was skipped, and why

- **iOS configuration** — the assignment lists iOS as optional and the time
  budget is 3–4 hours. The Dart code is iOS-clean (no Android-only APIs),
  but `Info.plist` permissions aren't wired up.
- **Custom camera UI with overlay guides** — `image_picker` was chosen over
  the raw `camera` plugin to stay within time. In production you'd absolutely
  want a card-shaped overlay and auto-capture.
- **Bank-name detection** — wasn't asked for; the parser could be extended
  to recognise the bank from the first 4 letters of the IFSC.
- **Card brand detection** (Visa/MC/Amex from BIN prefix) — not asked for,
  but trivial to add.
- **Persistence / history** — out of scope; results live only in memory.
- **Widget tests** — the brief requires "1 test per algorithm". Parser / Luhn
  tests are present; widget tests were skipped to focus on parser robustness
  (40% of the grade).

---

## Things I'd improve in production

- **Real-time scanning** with the `camera` plugin and a card-shaped overlay,
  auto-capturing once the number is in focus.
- **Frame averaging / multi-attempt OCR** — run OCR on several frames and
  vote on the digits to recover from single-frame misreads.
- **Confidence scores** — ML Kit exposes per-element confidence; combining
  that with the Luhn check would let us auto-retry low-confidence scans.
- **Localised passbook parsers** — keyword lists per country / language.
- **Telemetry on parsing failures** (with user consent) to drive a feedback
  loop for parser improvements.
#   a s s i g n m e n t  
 