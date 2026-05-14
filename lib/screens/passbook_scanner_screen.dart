import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/bank_details.dart';
import '../parsers/passbook_parser.dart';
import '../services/ocr_service.dart';

/// Passbook / bank document scanner.
///
/// Mostly the same shape as [CardScannerScreen] but renders different
/// fields. Kept as a separate class so each screen stays simple to read.
class PassbookScannerScreen extends StatefulWidget {
  const PassbookScannerScreen({super.key});

  @override
  State<PassbookScannerScreen> createState() => _PassbookScannerScreenState();
}

class _PassbookScannerScreenState extends State<PassbookScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocr = OcrService();

  File? _image;
  BankDetails? _details;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;

      setState(() {
        _image = File(picked.path);
        _details = null;
        _error = null;
        _loading = true;
      });

      final rawText = await _ocr.extractText(picked.path);
      if (rawText.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No text could be read from the image. Try a clearer photo.';
        });
        return;
      }

      final parsed = parsePassbook(rawText);
      setState(() {
        _loading = false;
        _details = parsed;
        if (parsed.isEmpty) {
          _error = 'Could not find any passbook details in the scan.';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Something went wrong: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passbook Scanner')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPreview(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    onPressed:
                        _loading ? null : () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    onPressed:
                        _loading ? null : () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _error != null) _ErrorBox(message: _error!),
            if (!_loading && _details != null && !_details!.isEmpty)
              _PassbookResult(details: _details!),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_image == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No image selected', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(_image!, height: 220, fit: BoxFit.cover),
    );
  }
}

class _PassbookResult extends StatelessWidget {
  final BankDetails details;
  const _PassbookResult({required this.details});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Extracted Bank Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _Row(label: 'Holder', value: details.accountHolderName ?? 'Not found'),
            _Row(label: 'Account', value: details.accountNumber ?? 'Not found'),
            _Row(label: 'IFSC', value: details.ifscCode ?? 'Not found'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
