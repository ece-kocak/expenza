# Expenza — Harcama Kategorizasyonu Model Sonuçları

Bu belge, hero özellik olan **Türkçe harcama kategorizasyon modelinin** geliştirme
sürecini, deneylerini ve sonuçlarını özetler. Doğrudan bitirme tezi metnine kaynak.

## Problem
Kullanıcının girdiği serbest metin not (örn. "migros market", "uber ile eve") 8
kategoriden birine atanır: **Yemek, Ulaşım, Faturalar, Eğlence, Sağlık, Eğitim,
Alışveriş, Diğer**.

## Veri
- **Eğitim:** Sentetik olarak üretildi (`generate_data.py`). Her kategori için gerçekçi
  Türk markaları/kalemleri + çeşitli cümle şablonları. Son sürüm: 200+ marka, 6400 satır.
- **Doğrulama (held-out):** `validation_set.csv` — eğitimde kullanılmayan, gerçek tarzda
  yazılmış 46 örnek. Modelin **genelleme** yeteneğini ölçer.

## Modeller
1. **Baseline:** TF-IDF (kelime 1-2gram + karakter 2-5gram, `strip_accents`) + kalibre
   Linear SVM. Hafif, CPU'da milisaniyeler, yorumlanabilir. **Üründe (backend) bu kullanılır.**
2. **BERTurk:** `dbmdz/bert-base-turkish-cased` fine-tune (3 epoch). Tez **kıyas** modeli.

## Sonuçlar

| Model | Sentetik test | Gerçek doğrulama (held-out) |
|---|---|---|
| Baseline — 24 marka | 0.99 | **0.52** |
| Baseline — zengin veri (200+ marka) | 0.99 | **0.935** |
| **BERTurk — fine-tune** | — | **0.978** |

### Yorum
- **Sentetik 0.99 → gerçek 0.52:** İlk baseline kelime dağarcığına aşırı uyum sağladı
  (overfitting). Görmediği markada çöktü.
- **Veri zenginleştirme 0.52 → 0.935:** Daha geniş marka kapsamı genellemeyi belirgin
  artırdı. (Not: bu sayı bir miktar iyimser — zengin eğitim verisi doğrulamadaki yaygın
  markaların çoğunu kapsıyor.)
- **BERTurk 0.978:** Türkçe ön-eğitim sayesinde, **eğitimde hiç görülmemiş** kelimeleri bile
  anlamından çözdü:

| Görülmemiş kelime | Baseline | BERTurk | Doğru |
|---|---|---|---|
| ekol hoca aboneliği | Diğer ❌ | Eğitim ✅ | Eğitim |
| anahtarcı | Yemek ❌ | Diğer ✅ | Diğer |
| maç bileti | Ulaşım ❌ | Eğlence ✅ | Eğlence |

BERTurk'ün tek hatası: `millenicom internet → Yemek` (çok küçük, bilinmeyen ISP markası).

## Mühendislik kararı
Üründe **baseline** kullanılır (hız, düşük kaynak, kolay dağıtım). BERTurk, ulaşılabilir
üst sınırı (ceiling) gösteren **kıyas** modelidir. Bu, "en iyi modeli kıyasla, hafif olanı
ürünleştir" şeklindeki yaygın endüstri yaklaşımıdır.

## Sınırlılıklar / gelecek iş
- Doğrulama seti küçük (46). Tarafsız nihai ölçüm için gerçek kullanıcı verisinden ~150+
  örnekli taze held-out set toplanmalı.
- "Diğer" kategorisinin sınırları bulanık (spor salonu, evcil hayvan vb.); taksonomi
  genişletilebilir.

## Tekrar üretim
```bash
python -m ml_training.generate_data     # veri üret
python -m ml_training.train_baseline    # baseline eğit + kaydet (üründe kullanılan)
python -m ml_training.evaluate          # gerçek sette dürüst değerlendir
python -m ml_training.berturk_train     # BERTurk kıyas (GPU gerekir)
```
