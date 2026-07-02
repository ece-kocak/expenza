"""Hero modeli GERÇEK doğrulama setinde değerlendir (dürüst metrik).

validation_set.csv eğitimde HİÇ kullanılmamış, gerçek tarzda yazılmış örnekler
içerir. Bu script eğitilmiş modeli o set üzerinde test eder ve tez için anlamlı
rakamları (doğruluk, makro F1, kategori bazında rapor, karışıklık matrisi) ve
en önemlisi **yanlış bildiği örnekleri** (hata analizi) yazdırır.

Çalıştırma:
    python -m ml_training.evaluate
"""
import os
import sys

import joblib
import pandas as pd

# Windows terminali cp1254 olabilir; Türkçe/ok karakterleri için UTF-8'e geç.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)

HERE = os.path.dirname(__file__)
VAL_PATH = os.path.join(HERE, "validation_set.csv")
MODEL_PATH = os.path.join(HERE, "..", "app", "ml", "model", "categorizer.joblib")


def main() -> None:
    model = joblib.load(MODEL_PATH)
    df = pd.read_csv(VAL_PATH)
    df = df.dropna(subset=["text", "label"])

    probs = model.predict_proba(df["text"])
    classes = list(model.classes_)
    pred = [classes[p.argmax()] for p in probs]
    conf = [float(p.max()) for p in probs]

    acc = accuracy_score(df["label"], pred)
    macro_f1 = f1_score(df["label"], pred, average="macro")

    print("=" * 60)
    print(f"GERÇEK DOĞRULAMA SETİ — {len(df)} örnek")
    print("=" * 60)
    print(f"Doğruluk (accuracy): {acc:.4f}")
    print(f"Makro F1           : {macro_f1:.4f}")
    print("\nKategori bazında rapor:")
    print(classification_report(df["label"], pred, zero_division=0))

    print("Karışıklık matrisi (satır=gerçek, sütun=tahmin):")
    cm = confusion_matrix(df["label"], pred, labels=classes)
    cm_df = pd.DataFrame(cm, index=classes, columns=classes)
    print(cm_df.to_string())

    # Hata analizi — tezde en kıymetli kısım
    print("\n" + "-" * 60)
    print("YANLIŞ TAHMİNLER (hata analizi):")
    errors = 0
    for text, gercek, tahmin, c in zip(df["text"], df["label"], pred, conf):
        if gercek != tahmin:
            errors += 1
            print(f"  '{text}'  →  tahmin: {tahmin} (%{c*100:.0f})  | doğru: {gercek}")
    if errors == 0:
        print("  (Hiç hata yok)")
    print(f"\nToplam {errors}/{len(df)} yanlış.")


if __name__ == "__main__":
    main()
