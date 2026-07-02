"""ML uçları — kategorizasyon (hero) ve ileride tahmin/anomali.

Bu uç, mobil uygulamada 'Harcama Ekle' ekranında not yazılırken canlı kategori
önerisi göstermek için kullanılır.
"""
from fastapi import APIRouter

from .. import schemas
from ..ml import categorizer

router = APIRouter(prefix="/ml", tags=["ml"])


@router.post("/categorize", response_model=schemas.CategorizeResponse)
def categorize(payload: schemas.CategorizeRequest):
    cat, conf, model = categorizer.categorize(payload.text)
    return schemas.CategorizeResponse(category=cat, confidence=conf, model=model)
