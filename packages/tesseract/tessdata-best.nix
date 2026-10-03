{ fetchurl }:

# Accuracy-first official models from tesseract-ocr/tessdata_best. Keep the
# revision fixed so Linux and Darwin publish identical, reproducible data.
{
  eng = fetchurl {
    url = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/e12c65a915945e4c28e237a9b52bc4a8f39a0cec/eng.traineddata";
    hash = "sha256-goCu0Hgv4nJXpo6hD+fvMkyg+Nhb0v0UXRwrVgvLZro=";
  };
  chi_sim = fetchurl {
    url = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/e12c65a915945e4c28e237a9b52bc4a8f39a0cec/chi_sim.traineddata";
    hash = "sha256-T+8tEwbI6HYW1NPkxsZ/r11EvjNCKQz48vD246p+c1s=";
  };
  chi_tra = fetchurl {
    url = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/e12c65a915945e4c28e237a9b52bc4a8f39a0cec/chi_tra.traineddata";
    hash = "sha256-GqYEiFdMr6aUhtkZKE8HnKm2j8x/atjcH/GzGN/ZcCg=";
  };
  osd = fetchurl {
    url = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/e12c65a915945e4c28e237a9b52bc4a8f39a0cec/osd.traineddata";
    hash = "sha256-nPXVdvzEdWTxEmWEHlyoOQAefm84/396rPRtFalrAP8=";
  };
}
