"""ML uçları — kategorizasyon (hero) ve ileride tahmin/anomali.

Bu uç, mobil uygulamada 'Harcama Ekle' ekranında not yazılırken canlı kategori
önerisi göstermek için kullanılır.
"""
from fastapi import APIRouter, Depends

from .. import ratelimit, schemas
from ..ml import categorizer

router = APIRouter(prefix="/ml", tags=["ml"])


# Giriş zorunlu ve kullanıcı başına sınırlı: CATEGORIZER=gemini iken her çağrı ücretli
# bir dış istek yapar.
@router.post(
    "/categorize",
    response_model=schemas.CategorizeResponse,
    dependencies=[Depends(ratelimit.limit_categorize)],
)
def categorize(payload: schemas.CategorizeRequest):
    cat, conf, model = categorizer.categorize(payload.text)
    return schemas.CategorizeResponse(category=cat, confidence=conf, model=model)
