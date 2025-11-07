from __future__ import annotations

import base64
import io
from functools import lru_cache
from typing import Dict, List

import cv2
import layoutparser as lp
import numpy as np
import pytesseract
from fastapi import FastAPI, File, Query, UploadFile
from fastapi.responses import JSONResponse
from fpdf import FPDF
from PIL import Image
from transformers import pipeline


app = FastAPI(title="OCR Pipeline API", version="1.0.0")


def preprocess_image(image: Image.Image) -> np.ndarray:
    """Apply basic preprocessing to improve OCR quality."""

    np_image = np.array(image)
    gray = cv2.cvtColor(np_image, cv2.COLOR_RGB2GRAY)
    denoised = cv2.bilateralFilter(gray, d=9, sigmaColor=75, sigmaSpace=75)
    _, thresholded = cv2.threshold(
        denoised, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
    )
    return thresholded


@lru_cache(maxsize=1)
def get_layout_model() -> lp.TesseractLayoutModel:
    """Return a cached instance of the layout parser model."""

    return lp.TesseractLayoutModel(config="--psm 6")


@lru_cache(maxsize=1)
def get_ner_pipeline():
    """Return a cached BioBERT-based NER pipeline."""

    return pipeline(
        "ner",
        model="d4data/biobert-medmentions-ner",
        aggregation_strategy="simple",
    )


def build_pdf_from_text(text: str) -> str:
    """Create a PDF from text content and return it as a base64 string."""

    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()
    pdf.set_font("Arial", size=12)

    for line in text.splitlines() or [text]:
        pdf.multi_cell(0, 10, line)

    pdf_bytes = pdf.output(dest="S").encode("latin1")
    return base64.b64encode(pdf_bytes).decode("ascii")


def extract_layout_text(
    processed_image: np.ndarray,
) -> Dict[str, List[Dict[str, float]] | str]:
    """Use layout parser and Tesseract to extract text segments."""

    layout_image = Image.fromarray(processed_image).convert("RGB")
    layout_model = get_layout_model()
    layout = layout_model.detect(layout_image)

    segments = []
    collected_text: List[str] = []
    for block in layout:
        if block.type != "Text":
            continue

        x_1, y_1, x_2, y_2 = map(int, block.coordinates)
        crop = processed_image[y_1:y_2, x_1:x_2]
        if crop.size == 0:
            continue

        crop_image = Image.fromarray(crop)
        text = pytesseract.image_to_string(crop_image, config="--psm 6")
        cleaned_text = text.strip()
        if not cleaned_text:
            continue

        collected_text.append(cleaned_text)
        segments.append(
            {
                "text": cleaned_text,
                "bbox": [x_1, y_1, x_2, y_2],
                "type": block.type,
                "score": float(block.score) if block.score is not None else None,
            }
        )

    full_text = "\n".join(collected_text)
    return {"text": full_text, "segments": segments}


def run_biobert_ner(text: str) -> List[Dict[str, float | str]]:
    """Run the BioBERT model to extract medical entities."""

    if not text.strip():
        return []

    nlp = get_ner_pipeline()
    # Split text into manageable chunks to avoid hitting model limits.
    max_chunk_length = 400
    chunks: List[str] = []
    current_chunk: List[str] = []
    current_length = 0

    for sentence in text.splitlines():
        sentence = sentence.strip()
        if not sentence:
            continue
        if current_length + len(sentence) > max_chunk_length:
            if current_chunk:
                chunks.append(" ".join(current_chunk))
            current_chunk = [sentence]
            current_length = len(sentence)
        else:
            current_chunk.append(sentence)
            current_length += len(sentence)
    if current_chunk:
        chunks.append(" ".join(current_chunk))

    entities: List[Dict[str, float | str]] = []
    for chunk in chunks:
        predictions = nlp(chunk)
        for entity in predictions:
            entities.append(
                {
                    "entity": entity.get("entity_group"),
                    "score": float(entity.get("score", 0.0)),
                    "text": entity.get("word"),
                    "start": int(entity.get("start", 0)),
                    "end": int(entity.get("end", 0)),
                }
            )

    return entities


@app.post("/ocr/")
async def perform_ocr(
    file: UploadFile = File(...),
    output: str = Query(
        "text", regex=r"^(text|pdf|both)$", description="Desired output format"
    ),
):
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        processed = preprocess_image(image)
        ocr_result = extract_layout_text(processed)

        full_text = ocr_result["text"]
        entities = run_biobert_ner(full_text)

        response_payload: Dict[str, object] = {
            "text": full_text,
            "segments": ocr_result["segments"],
            "entities": entities,
        }

        if output in {"pdf", "both"}:
            response_payload["pdf_base64"] = build_pdf_from_text(full_text)

        return JSONResponse(response_payload)
    except Exception as exc:  # pragma: no cover - runtime safeguard
        return JSONResponse({"error": str(exc)}, status_code=500)
