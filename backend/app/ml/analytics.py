"""İP-4 — Harcama tahmini ve anomali tespiti.

Tasarım ilkesi: az veriyle bile çalışan, AÇIKLANABİLİR yöntemler. Bir finans
uygulamasında kullanıcıya "neden" söylenebilmesi, kara-kutu doğruluğundan önemlidir.

- Tahmin: (1) içinde bulunulan ay için koşu-hızı (run-rate) projeksiyonu,
          (2) tamamlanmış aylık toplamlardan doğrusal trend ile gelecek ay tahmini.
- Anomali: kategori bazında istatistiksel aykırılık (z-skoru). Bir harcama, kendi
           kategorisindeki ortalamadan yeterince saparsa işaretlenir.
"""
from __future__ import annotations

import calendar
import statistics
from collections import defaultdict
from datetime import date

from ..models import Transaction, TxType


def _month_key(d: date) -> tuple[int, int]:
    return (d.year, d.month)


def _expenses(txs: list[Transaction]) -> list[Transaction]:
    return [t for t in txs if t.type == TxType.expense]


def forecast_spending(txs: list[Transaction], today: date | None = None) -> dict:
    """Gelecek ay ve ay-sonu harcama tahmini döndürür."""
    today = today or date.today()
    exp = _expenses(txs)

    # Aylık toplamlar
    monthly: dict[tuple[int, int], float] = defaultdict(float)
    for t in exp:
        monthly[_month_key(t.occurred_on)] += t.amount

    cur_key = (today.year, today.month)
    cur_spent = monthly.get(cur_key, 0.0)

    # Koşu-hızı: bu ayki harcamayı geçen güne göre ay sonuna projekte et
    days_in_month = calendar.monthrange(today.year, today.month)[1]
    days_elapsed = max(today.day, 1)
    projected_month_end = cur_spent / days_elapsed * days_in_month

    # Tamamlanmış aylar (bu ay hariç), tarihe göre sıralı
    complete = sorted((k, v) for k, v in monthly.items() if k != cur_key)
    history = [{"month": f"{y}-{m:02d}", "total": round(v, 2)} for (y, m), v in complete]

    if len(complete) >= 2:
        # Doğrusal trend: ay indeksine karşı toplam; en küçük kareler eğimi
        ys = [v for _, v in complete]
        n = len(ys)
        xs = list(range(n))
        mean_x = sum(xs) / n
        mean_y = sum(ys) / n
        denom = sum((x - mean_x) ** 2 for x in xs) or 1.0
        slope = sum((xs[i] - mean_x) * (ys[i] - mean_y) for i in range(n)) / denom
        intercept = mean_y - slope * mean_x
        next_pred = max(0.0, intercept + slope * n)
        method = "trend"
    elif len(complete) == 1:
        next_pred = complete[-1][1]
        method = "last_month"
    else:
        next_pred = projected_month_end
        method = "run_rate"

    # Harcama hızı: ay-sonu projeksiyonu, geçmiş ortalamaya göre nasıl?
    if complete:
        avg_hist = statistics.mean(v for _, v in complete)
        if projected_month_end > avg_hist * 1.15:
            velocity = "Yüksek"
        elif projected_month_end < avg_hist * 0.85:
            velocity = "Düşük"
        else:
            velocity = "Normal"
    else:
        velocity = "Normal"

    # Kategori bazında ay-sonu projeksiyonu
    cur_by_cat: dict[str, float] = defaultdict(float)
    for t in exp:
        if _month_key(t.occurred_on) == cur_key:
            cur_by_cat[t.category.value] += t.amount
    by_category = sorted(
        ({"category": c, "projected": round(v / days_elapsed * days_in_month, 2)}
         for c, v in cur_by_cat.items()),
        key=lambda d: d["projected"], reverse=True,
    )

    return {
        "current_month_spent": round(cur_spent, 2),
        "projected_month_end": round(projected_month_end, 2),
        "next_month_prediction": round(next_pred, 2),
        "method": method,
        "velocity": velocity,
        "history": history,
        "by_category": by_category,
    }


def detect_anomalies(
    txs: list[Transaction],
    z_threshold: float = 2.5,
    min_samples: int = 4,
) -> list[dict]:
    """Kategori bazında istatistiksel aykırı harcamaları işaretler.

    Bir kategoride yeterli örnek varsa (>= min_samples), o kategorideki her harcama
    z-skoru ile değerlendirilir. Eşiği aşan ve ortalamanın ÜSTÜNDE olanlar (yüksek
    harcamalar) uyarı olarak döner.
    """
    exp = _expenses(txs)
    by_cat: dict[str, list[Transaction]] = defaultdict(list)
    for t in exp:
        by_cat[t.category.value].append(t)

    anomalies: list[dict] = []
    for cat, items in by_cat.items():
        if len(items) < min_samples:
            continue
        amounts = [t.amount for t in items]
        mean = statistics.mean(amounts)
        std = statistics.pstdev(amounts)
        if std == 0:
            continue
        for t in items:
            z = (t.amount - mean) / std
            if z >= z_threshold and t.amount > mean:
                ratio = t.amount / mean if mean else 0
                anomalies.append({
                    "transaction_id": t.id,
                    "amount": round(t.amount, 2),
                    "category": cat,
                    "note": t.note,
                    "occurred_on": t.occurred_on.isoformat(),
                    "z_score": round(z, 2),
                    "severity": "high" if z >= 3.5 else "medium",
                    "reason": f"{cat} kategorisinde ortalamanın {ratio:.1f} katı "
                              f"(₺{mean:.0f} ort.)",
                })

    anomalies.sort(key=lambda a: a["z_score"], reverse=True)
    return anomalies[:10]
