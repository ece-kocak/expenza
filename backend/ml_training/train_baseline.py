"""Baseline hero model eğitimi — TF-IDF + (kalibre) Linear SVM.

Colab'da doğrulanan boru hattının repo sürümü. Tek fark: olasılık (güven skoru)
üretebilmek için LinearSVC, CalibratedClassifierCV ile sarılır — böylece backend
'%85 güvenle Alışveriş' gibi anlamlı bir skor döndürebilir.

Model `app/ml/model/categorizer.joblib` olarak kaydedilir ve backend açılışta yükler.

Çalıştırma:
    python -m ml_training.train_baseline
"""
import os

import joblib
import pandas as pd
from sklearn.calibration import CalibratedClassifierCV
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics import accuracy_score, classification_report, f1_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import FeatureUnion, Pipeline
from sklearn.svm import LinearSVC

HERE = os.path.dirname(__file__)
DATA_PATH = os.path.join(HERE, "data", "expenza_data.csv")
MODEL_DIR = os.path.join(HERE, "..", "app", "ml", "model")
MODEL_PATH = os.path.join(MODEL_DIR, "categorizer.joblib")


def build_model() -> Pipeline:
    # Kelime + karakter özniteliklerini birleştir; strip_accents Türkçe karaktersiz
    # yazımı (ilac~ilaç) tolere eder, char_wb ekleri (eczaneden~eczane) yakalar.
    word_tfidf = TfidfVectorizer(
        analyzer="word", ngram_range=(1, 2), min_df=2,
        sublinear_tf=True, strip_accents="unicode", lowercase=True,
    )
    char_tfidf = TfidfVectorizer(
        analyzer="char_wb", ngram_range=(2, 5), min_df=2,
        sublinear_tf=True, strip_accents="unicode", lowercase=True,
    )
    features = FeatureUnion([("word", word_tfidf), ("char", char_tfidf)])
    return Pipeline([
        ("features", features),
        ("clf", CalibratedClassifierCV(LinearSVC(C=1.0), method="sigmoid", cv=3)),
    ])


def main() -> None:
    df = pd.read_csv(DATA_PATH)
    X_train, X_test, y_train, y_test = train_test_split(
        df["text"], df["label"],
        test_size=0.2, random_state=42, stratify=df["label"],
    )

    model = build_model()
    model.fit(X_train, y_train)
    pred = model.predict(X_test)

    print("Doğruluk (accuracy):", round(accuracy_score(y_test, pred), 4))
    print("Makro F1:", round(f1_score(y_test, pred, average="macro"), 4))
    print("\nDetaylı rapor:\n", classification_report(y_test, pred))

    # Görülmemiş gerçek örneklerle hızlı kontrol
    ornekler = [
        "Trendyol siparişi", "yemeksepeti akşam yemeği", "elektrik faturası ödedim",
        "uber ile eve döndüm", "eczaneden ilaç", "spotify aboneliği",
    ]
    print("Görülmemiş örnekler:")
    for s in ornekler:
        proba = model.predict_proba([s])[0]
        idx = proba.argmax()
        print(f"  {s:35s} -> {model.classes_[idx]:10s} (%{proba[idx]*100:.0f})")

    os.makedirs(MODEL_DIR, exist_ok=True)
    joblib.dump(model, MODEL_PATH)
    print(f"\nModel kaydedildi -> {os.path.abspath(MODEL_PATH)}")


if __name__ == "__main__":
    main()
