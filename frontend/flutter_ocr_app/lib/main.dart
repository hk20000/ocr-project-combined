import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  List<dynamic> _entities = [];
  List<dynamic> _segments = [];
  String? _savedPdfPath;
  String? _errorMessage;

  static const String _baseUrl = 'http://localhost:8000';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _recognizedText = null;
          _entities = [];
          _segments = [];
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

    final uri = Uri.parse('$_baseUrl/ocr/?output=$_outputFormat');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', _selectedImage!.path));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) {
        throw HttpException('Request failed: ${response.statusCode}');
      }

      final Map<String, dynamic> payload = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        _recognizedText = payload['text'] as String?;
        _entities = (payload['entities'] as List<dynamic>? ?? []);
        _segments = (payload['segments'] as List<dynamic>? ?? []);
      });

      if ((_outputFormat == 'pdf' || _outputFormat == 'both') &&
          payload['pdf_base64'] != null) {
        await _savePdf(payload['pdf_base64'] as String);
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

  Future<void> _savePdf(String base64Data) async {
    final bytes = base64Decode(base64Data);
    final directory = await getApplicationDocumentsDirectory();
    final filename =
        'ocr_output_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
    if (_entities.isEmpty) {
      return const Text('No medical entities detected yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _entities
          .map((entity) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(entity['text']?.toString() ?? ''),
                  subtitle: Text(
                    '${entity['entity']} • ${(entity['score'] as num?)?.toStringAsFixed(2) ?? '0.0'}',
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSegments() {
    if (_segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      title: const Text('OCR Segments'),
      children: _segments
          .map((segment) => ListTile(
                title: Text(segment['text']?.toString() ?? ''),
                subtitle: Text('Box: ${segment['bbox']}'),
              ))
          .toList(),
    );
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
        const Text(
          'Detected Medical Entities',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildEntities(),
        const SizedBox(height: 16),
        _buildSegments(),
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
          'When running on a mobile emulator, replace "localhost" with\n'
          '• Android Emulator: http://10.0.2.2:8000\n'
          '• iOS Simulator: http://127.0.0.1:8000\n'
          'For physical devices, ensure both the backend server and device are on the same network.'
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
