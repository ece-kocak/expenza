"""BERTurk fine-tune — KIYAS (benchmark) modeli. GPU gerektirir.

ÖNEMLİ: Bu script tez için KIYAS modelini üretir; üründe (backend) hafif baseline
(train_baseline.py) kullanılır. BERTurk burada yalnızca baseline ile karşılaştırma
amacıyla eğitilir.

Pratikte Google Colab'da (T4 GPU) çalıştırıldı. Colab'da tek fark, expenza_data.csv
ve validation_set.csv dosyalarının `files.upload()` ile yüklenmesiydi; burada repodaki
yerel kopyalar okunur. GPU yoksa eğitim çok yavaş olur.

Sonuç (gerçek doğrulama seti, 46 görülmemiş örnek):
    Baseline (24 marka)      : 0.52
    Baseline (zengin veri)   : 0.935
    BERTurk (bu script)      : 0.978

Çalıştırma (GPU'lu ortamda):
    pip install transformers datasets accelerate torch
    python -m ml_training.berturk_train
"""
import os

import pandas as pd
from datasets import Dataset
from sklearn.metrics import accuracy_score, classification_report, f1_score
from transformers import (
    AutoModelForSequenceClassification,
    AutoTokenizer,
    DataCollatorWithPadding,
    Trainer,
    TrainingArguments,
)

MODEL_NAME = "dbmdz/bert-base-turkish-cased"
HERE = os.path.dirname(__file__)
TRAIN_CSV = os.path.join(HERE, "data", "expenza_data.csv")
VAL_CSV = os.path.join(HERE, "validation_set.csv")


def main() -> None:
    train_df = pd.read_csv(TRAIN_CSV)
    val_df = pd.read_csv(VAL_CSV)

    labels = sorted(train_df["label"].unique())
    label2id = {l: i for i, l in enumerate(labels)}
    id2label = {i: l for l, i in label2id.items()}
    train_df["labels"] = train_df["label"].map(label2id)
    val_df["labels"] = val_df["label"].map(label2id)

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

    def tok(batch):
        return tokenizer(batch["text"], truncation=True, max_length=32)

    train_ds = Dataset.from_pandas(train_df[["text", "labels"]]).map(tok, batched=True)
    val_ds = Dataset.from_pandas(val_df[["text", "labels"]]).map(tok, batched=True)

    model = AutoModelForSequenceClassification.from_pretrained(
        MODEL_NAME, num_labels=len(labels), id2label=id2label, label2id=label2id
    )

    args = TrainingArguments(
        output_dir="berturk_out",
        num_train_epochs=3,
        per_device_train_batch_size=32,
        per_device_eval_batch_size=64,
        learning_rate=2e-5,
        logging_steps=50,
        report_to="none",
    )
    trainer = Trainer(
        model=model,
        args=args,
        train_dataset=train_ds,
        data_collator=DataCollatorWithPadding(tokenizer),
    )
    trainer.train()

    # Gerçek doğrulama setinde değerlendir
    pred = trainer.predict(val_ds).predictions.argmax(-1)
    y = val_df["labels"].values
    print(f"\nBERTurk — gerçek doğrulama: acc={accuracy_score(y, pred):.4f} "
          f"| makro F1={f1_score(y, pred, average='macro'):.4f}")
    print(classification_report(y, pred, target_names=labels, zero_division=0))


if __name__ == "__main__":
    main()
