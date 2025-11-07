# OCR + BioBERT Medical Document Pipeline

This repository contains a complete medical document processing stack:

* **FastAPI backend** (`backend/`) that performs image preprocessing, layout
  analysis with [Layout Parser](https://layout-parser.github.io/), OCR via
  Tesseract, and medical named-entity recognition using a BioBERT model.
* **Flutter mobile client** (`frontend/flutter_ocr_app/`) for Android and iOS
  that captures documents, submits them to the backend, and displays the OCR
  output, detected medical terms, and optional generated PDF files.

## Backend quick start

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Upload an image to `POST /ocr/` with a multipart request. Choose an output
format using the `output` query parameter (`text`, `pdf`, or `both`). The
response includes:

* Preprocessed OCR text and bounding-box segments.
* Detected medical entities produced by BioBERT.
* (Optional) Base64-encoded PDF rendition of the OCR output.

## Flutter client

See `frontend/flutter_ocr_app/README.md` for setup instructions. The default API
base URL is `http://localhost:8000`; update it in `lib/main.dart` if needed for
emulators or physical devices.
