"""ML uçları — kategorizasyon (hero) ve ileride tahmin/anomali.

Bu uç, mobil uygulamada 'Harcama Ekle' ekranında not yazılırken canlı kategori
önerisi göstermek için kullanılır.
"""
from fastapi import APIRouter, Depends

from .. import schemas
from ..auth import get_current_user
from ..ml import categorizer

router = APIRouter(prefix="/ml", tags=["ml"])


# Giriş zorunlu: Gemini anahtarı tanımlıysa her çağrı ücretli bir dış istek yapar.
@router.post(
    "/categorize",
    response_model=schemas.CategorizeResponse,
    dependencies=[Depends(get_current_user)],
)
def categorize(payload: schemas.CategorizeRequest):
    cat, conf, model = categorizer.categorize(payload.text)
    return schemas.CategorizeResponse(category=cat, confidence=conf, model=model)
