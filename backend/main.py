from fastapi import FastAPI, File, UploadFile
from PIL import Image
import pytesseract
import io

app = FastAPI()

@app.post("/ocr/")
async def perform_ocr(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        text = pytesseract.image_to_string(image)
        return {"text": text}
    except Exception as e:
        return {"error": str(e)}
