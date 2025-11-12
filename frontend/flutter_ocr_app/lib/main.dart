import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  runApp(const MedicalOcrApp());
}

class MedicalOcrApp extends StatelessWidget {
  const MedicalOcrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical OCR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const OcrHomePage(),
    );
  }
}

class OcrHomePage extends StatefulWidget {
  const OcrHomePage({super.key});

  @override
  State<OcrHomePage> createState() => _OcrHomePageState();
}

class _OcrHomePageState extends State<OcrHomePage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isProcessing = false;
  String _outputFormat = 'text';
  String? _recognizedText;
  // Entities/segments are backend features; omitted for on-device OCR.
  String? _savedPdfPath;
  String? _errorMessage;


  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _recognizedText = null;
          _savedPdfPath = null;
          _errorMessage = null;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Image selection failed: $error';
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Please select an image first.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Run on-device OCR with Tesseract (uses assets/tessdata for traineddata).
      final text = await FlutterTesseractOcr.extractText(
        _selectedImage!.path,
        language: 'eng',
      );

      if (!mounted) return;

      setState(() {
        _recognizedText = text;
      });

      if (_outputFormat == 'pdf' || _outputFormat == 'both') {
        await _savePdfFromText(text ?? '');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Processing failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _savePdfFromText(String text) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(text, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
    final bytes = await pdf.save();
    final directory = await getApplicationDocumentsDirectory();
    final filename = 'ocr_output_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    setState(() {
      _savedPdfPath = file.path;
    });
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) {
      return const Placeholder(
        fallbackHeight: 200,
        fallbackWidth: double.infinity,
      );
    }

    return Image.file(
      File(_selectedImage!.path),
      height: 240,
      fit: BoxFit.contain,
    );
  }

  Widget _buildEntities() {
    // Entities are not produced in on-device OCR mode.
    return const SizedBox.shrink();
  }

  Widget _buildSegments() {
    // Bounding boxes not shown in this simplified setup.
    return const SizedBox.shrink();
  }

  Widget _buildResults() {
    if (_isProcessing) {
      return const Center(
        child: SpinKitCircle(color: Colors.teal),
      );
    }

    if (_errorMessage != null) {
      return Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recognizedText != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recognized Text',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.teal.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(_recognizedText ?? ''),
              ),
              const SizedBox(height: 16),
            ],
          ),
        // No entities/segments in on-device mode
        if (_savedPdfPath != null) ...[
          const SizedBox(height: 16),
          Text('Saved PDF: $_savedPdfPath'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => Share.shareXFiles([
              XFile(_savedPdfPath!),
            ]),
            icon: const Icon(Icons.share),
            label: const Text('Share PDF'),
          ),
        ],
      ],
    );
  }

  void _showConnectionTips(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Tips'),
        content: const Text(
          'This build uses on-device OCR (Tesseract).\n'
          'No backend connection is required.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical OCR Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showConnectionTips(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildImagePreview()),
                const SizedBox(width: 16),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Output Format',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'text', label: Text('Text Only')),
                ButtonSegment(value: 'pdf', label: Text('PDF Only')),
                ButtonSegment(value: 'both', label: Text('Text + PDF')),
              ],
              selected: <String>{_outputFormat},
              onSelectionChanged: (selection) {
                setState(() {
                  _outputFormat = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _processImage,
                icon: const Icon(Icons.document_scanner),
                label: const Text('Run Medical OCR'),
              ),
            ),
            const SizedBox(height: 24),
            _buildResults(),
          ],
        ),
      ),
    );
  }
}
