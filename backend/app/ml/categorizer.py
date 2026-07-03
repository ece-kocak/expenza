"""Harcama kategorizasyonu — model arayüzü.

ÖNEMLİ (mimari karar): Burası projenin "hero" bileşeninin servis noktasıdır.
Şu an kural/anahtar-kelime tabanlı bir STUB ile çalışır; böylece backend ve mobil
uygulama bugün uçtan uca test edilebilir. İP-3'te eğitilen gerçek model
(TF-IDF+SVM baseline, ardından BERTurk) `predict()` arkasına takılacak —
çağıran kodun hiç değişmesine gerek kalmayacak.

Tüm modeller şu sözleşmeyi uygular:
    predict(text: str) -> (category: str, confidence: float)
"""
from __future__ import annotations

from ..models import CategoryEnum

# Kural-tabanlı stub için anahtar kelime sözlüğü.
# Aynı sözlük ileride sentetik eğitim verisi üretiminde de çekirdek olarak kullanılabilir.
KEYWORDS: dict[CategoryEnum, list[str]] = {
    CategoryEnum.yemek: [
        "kahve", "starbucks", "migros", "yemeksepeti", "getir", "lokanta",
        "restoran", "market", "cafe", "kafe", "pizza", "burger", "döner",
        "su", "ekmek", "bakkal", "yemek",
    ],
    CategoryEnum.ulasim: [
        "uber", "taksi", "iett", "metro", "otobüs", "benzin", "akaryakıt",
        "bilet", "marti", "scooter", "tren", "ido", "köprü", "otopark",
        "bitaksi", "ulaşım",
    ],
    CategoryEnum.faturalar: [
        "elektrik", "su faturası", "doğalgaz", "internet", "telefon faturası",
        "fatura", "turkcell", "vodafone", "türk telekom", "aidat", "kira",
    ],
    CategoryEnum.eglence: [
        "sinema", "netflix", "spotify", "konser", "oyun", "steam", "tiyatro",
        "bar", "bira", "eğlence", "youtube", "bilet",
    ],
    CategoryEnum.saglik: [
        "eczane", "hastane", "doktor", "ilaç", "muayene", "diş", "gözlük",
        "sağlık", "klinik", "tahlil",
    ],
    CategoryEnum.egitim: [
        "kitap", "kurs", "udemy", "okul", "kırtasiye", "kalem", "defter",
        "eğitim", "ders", "sınav", "yurt",
    ],
    CategoryEnum.alisveris: [
        "trendyol", "hepsiburada", "amazon", "zara", "giyim", "ayakkabı",
        "mağaza", "alışveriş", "h&m", "lcw", "elektronik", "teknosa",
    ],
}


class RuleBasedCategorizer:
    """Yedek stub. Eğitilmiş model bulunamazsa devreye girer."""

    name = "rule-stub-v1"

    def predict(self, text: str) -> tuple[CategoryEnum, float]:
        t = (text or "").lower().strip()
        if not t:
            return CategoryEnum.diger, 0.0

        best_cat = CategoryEnum.diger
        best_hits = 0
        for cat, words in KEYWORDS.items():
            hits = sum(1 for w in words if w in t)
            if hits > best_hits:
                best_hits, best_cat = hits, cat

        if best_hits == 0:
            return CategoryEnum.diger, 0.3
        # Kaba bir güven skoru: eşleşme sayısıyla artan, 0.95 tavanlı.
        confidence = min(0.5 + 0.15 * best_hits, 0.95)
        return best_cat, confidence


class MLCategorizer:
    """Eğitilmiş baseline model (TF-IDF + kalibre Linear SVM).

    ml_training/train_baseline.py tarafından üretilen joblib dosyasını yükler.
    predict_proba ile gerçek güven skoru döndürür.
    """

    name = "baseline-svm-v1"

    def __init__(self, pipeline):
        self._pipe = pipeline

    def predict(self, text: str) -> tuple[CategoryEnum, float]:
        t = (text or "").strip()
        if not t:
            return CategoryEnum.diger, 0.0
        proba = self._pipe.predict_proba([t])[0]
        idx = proba.argmax()
        label = self._pipe.classes_[idx]
        return CategoryEnum(label), float(proba[idx])


def _load_active():
    """Eğitilmiş model varsa onu, yoksa kural-tabanlı stub'ı döndürür."""
    import os

    model_path = os.path.join(os.path.dirname(__file__), "model", "categorizer.joblib")
    if os.path.exists(model_path):
        try:
            import joblib

            pipeline = joblib.load(model_path)
            print(f"[categorizer] Eğitilmiş model yüklendi: {model_path}")
            return MLCategorizer(pipeline)
        except Exception as e:  # bozuk dosya / sürüm sorunu => stub'a düş
            print(f"[categorizer] Model yüklenemedi ({e}); stub kullanılıyor.")
    else:
        print("[categorizer] Eğitilmiş model bulunamadı; stub kullanılıyor.")
    return RuleBasedCategorizer()


class GeminiCategorizer:
    name = "gemini-classifier-v1"

    def predict(self, text: str) -> tuple[Optional[CategoryEnum], float]:
        import os
        import httpx
        import json

        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            return None, 0.0

        t = (text or "").strip()
        if not t:
            return CategoryEnum.diger, 0.0

        prompt = (
            f"Sen bir finansal işlem sınıflandırıcısısın. Sana verilecek Türkçe not/açıklamayı en uygun harcama kategorisine ata.\n"
            f"Mevcut kategoriler: Yemek, Ulaşım, Faturalar, Eğlence, Sağlık, Eğitim, Alışveriş, Diğer\n\n"
            f"Not: \"{t}\"\n\n"
            f"Cevabını SADECE JSON formatında şu anahtarlarla dön:\n"
            f"{{\n"
            f"  \"category\": \"<KategoriAdı>\",\n"
            f"  \"confidence\": <0.0-1.0 arasında güven skoru float>\n"
            f"}}\n"
            f"Başka hiçbir açıklama, markdown işareti veya ek metin ekleme."
        )

        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
            headers = {"Content-Type": "application/json"}
            payload = {
                "contents": [
                    {
                        "parts": [
                            {"text": prompt}
                        ]
                    }
                ]
            }
            response = httpx.post(url, headers=headers, json=payload, timeout=5.0)
            if response.status_code == 200:
                data = response.json()
                text_response = data["candidates"][0]["content"]["parts"][0]["text"].strip()
                if text_response.startswith("```"):
                    text_response = text_response.split("```")[1]
                    if text_response.startswith("json"):
                        text_response = text_response[4:]
                
                res_json = json.loads(text_response.strip())
                cat_str = res_json.get("category", "Diğer")
                confidence = float(res_json.get("confidence", 0.9))
                
                for enum_val in CategoryEnum:
                    if enum_val.value.lower() == cat_str.lower():
                        return enum_val, confidence
                return CategoryEnum.diger, confidence
        except Exception as e:
            print(f"[categorizer] Gemini sınıflandırma hatası ({e}); fallback kullanılıyor.")
            
        return None, 0.0


# Aktif kategorizer (açılışta bir kez yüklenir).
_active = _load_active()
_gemini = GeminiCategorizer()


def categorize(text: str) -> tuple[CategoryEnum, float, str]:
    """(kategori, güven, model_adı) döndürür."""
    # Önce Gemini ile tahmin etmeyi dene
    cat, conf = _gemini.predict(text)
    if cat is not None:
        return cat, conf, _gemini.name

    # Gemini başarısızsa yerel aktif modele (SVM/Stub) düş
    cat, conf = _active.predict(text)
    return cat, conf, _active.name
