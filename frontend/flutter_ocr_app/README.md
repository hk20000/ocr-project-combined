# Medical OCR Flutter App

This Flutter client consumes the FastAPI backend located in `../../backend` to
process medical documents. The pipeline performs:

1. **Image preprocessing** to enhance OCR quality.
2. **Layout parsing** with [Layout Parser](https://layout-parser.github.io/) to
   split the document into logical blocks.
3. **Tesseract OCR** on each detected block.
4. **BioBERT-based named entity recognition** to highlight medical terms.
5. Optional **PDF generation** that contains the recognized text.

## Getting started

1. Install Flutter (version 3.13+ is recommended) by following the
   [official documentation](https://docs.flutter.dev/get-started/install).
2. Create a new Flutter project and replace its `pubspec.yaml` and
   `lib/main.dart` files with the ones in this directory **or** copy this
   folder into an existing Flutter workspace.
3. Run `flutter pub get` to download dependencies.
4. Start the FastAPI backend:
   ```bash
   uvicorn main:app --reload --port 8000
   ```
5. Update the `_baseUrl` constant in `lib/main.dart` if you are not running the
   backend on the same machine/emulator (e.g., use `http://10.0.2.2:8000` for
   the Android emulator).
6. Launch the app:
   ```bash
   flutter run
   ```

The app lets you capture or select a document image, choose the desired output
format (text, PDF, or both), and view the recognized text, detected medical
entities, and saved PDF path. Use the "Share PDF" button to share the generated
report directly from your device.
