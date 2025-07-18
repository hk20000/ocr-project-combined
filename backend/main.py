import io

from fastapi import FastAPI, File, UploadFile
from paddleocr import PaddleOCR
from PIL import Image

app = FastAPI()
ocr = PaddleOCR(use_angle_cls=True, lang='en')

@app.post("/ocr/")
async def perform_ocr(file: UploadFile = File(...)):
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")
    result = ocr.ocr(image, cls=True)

    extracted_text = "\n".join([line[1][0] for line in result[0]])
    return {"text": extracted_text}
