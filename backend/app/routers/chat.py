from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import httpx
from pydantic import BaseModel

from .. import models
from ..auth import get_current_user
from ..config import settings
from ..database import get_db

router = APIRouter(prefix="/chat", tags=["chat"])

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    reply: str

@router.post("", response_model=ChatResponse)
async def chat_with_gemini(
    payload: ChatRequest,
    db: Session = Depends(get_db),
    user: models.User = Depends(get_current_user),
):
    api_key = settings.gemini_api_key
    if not api_key:
        return ChatResponse(
            reply="Merhaba! Ben Expenza AI. Size yardımcı olabilmem için lütfen backend tarafında `GEMINI_API_KEY` ortam değişkenini tanımlayın."
        )

    # 1. Kullanıcı bilgilerini çekelim
    # Son 30 işlem
    transactions = (
        db.query(models.Transaction)
        .filter(models.Transaction.user_id == user.id)
        .order_by(models.Transaction.occurred_on.desc(), models.Transaction.id.desc())
        .limit(30)
        .all()
    )
    
    # Bütçe limitleri
    budgets = (
        db.query(models.Budget)
        .filter(models.Budget.user_id == user.id)
        .all()
    )
    
    # Hedefler
    goals = (
        db.query(models.Goal)
        .filter(models.Goal.user_id == user.id)
        .all()
    )

    # 2. Verileri yapay zekanın anlayacağı metin formatına çevirelim
    tx_list = []
    for t in transactions:
        tx_list.append(
            f"- {t.occurred_on}: {t.type.value.upper()} | {t.category.value} | {t.amount}₺ | Açıklama: {t.note}"
        )
    tx_summary = "\n".join(tx_list) if tx_list else "Henüz işlem kaydı yok."

    budget_list = []
    for b in budgets:
        budget_list.append(
            f"- {b.category.value}: Limit {b.monthly_limit}₺"
        )
    budget_summary = "\n".join(budget_list) if budget_list else "Belirlenmiş bir bütçe limiti yok."

    goal_list = []
    for g in goals:
        goal_list.append(
            f"- {g.title}: Hedef {g.target_amount}₺, Biriken {g.current_amount}₺, Hedef Tarihi: {g.deadline or 'Belirtilmedi'}"
        )
    goal_summary = "\n".join(goal_list) if goal_list else "Tanımlanmış bir tasarruf hedefi yok."

    # 3. Gemini Prompt'unu oluşturalım
    system_instruction = f"""Sen Expenza uygulamasının kişisel finans yapay zekâ asistanısın. 
Kullanıcının ismi: {user.display_name}.
Kullanıcının finansal durumu:

[Bütçeler]
{budget_summary}

[Tasarruf Hedefleri]
{goal_summary}

[Son 30 İşlem]
{tx_summary}

Kurallar:
- Yanıtlarını her zaman Türkçe olarak ver.
- Kibar, motive edici, finansal disiplini teşvik eden ve profesyonel bir dil kullan.
- Para birimini her zaman Türk Lirası (₺) olarak belirt.
- Markdown formatını kullanarak yanıt ver (kalın yazım, listeler vb. kullanarak okunabilirliği artır).
- Kullanıcı harcamalarını analiz etmek istediğinde veya bütçe durumu sorduğunda yukarıdaki verileri analiz et ve doğrudan veriler üzerinden cevap ver.
- Eğer kullanıcı harcamalarını aşmışsa tatlı ve uyarıcı bir dille uyar.
- Harcama eklemekle ilgili bir soru sorarsa uygulamadaki '+' butonunu kullanmasını söyle.
"""

    gemini_url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
    
    # Gemini API formatına uygun JSON gövdesi
    body = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": f"{system_instruction}\n\nKullanıcının Sorusu: {payload.message}"}
                ]
            }
        ]
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(gemini_url, json=body)
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Gemini API hata döndürdü: {response.text}"
                )
            
            res_json = response.json()
            reply = res_json["candidates"][0]["content"]["parts"][0]["text"]
            return ChatResponse(reply=reply)
            
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Chatbot servisinde bir hata oluştu: {str(e)}"
        )
