import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Thin wrapper around ML Kit so the rest of the app doesn't need to
/// know which OCR engine is plugged in.
///
/// The recogniser holds native resources, so always call [dispose]
/// when you're done (the screens do this in their State.dispose).
class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Run OCR on the image at [imagePath] and return the full raw text.
  /// Returns an empty string if ML Kit can't read anything.
  Future<String> extractText(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  Future<void> dispose() => _recognizer.close();
}
