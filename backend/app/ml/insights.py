"""Finansal içgörüler — verilerden doğal dilde, kişisel gözlemler üretir.

Raporun "finansal okuryazarlık / farkındalık" hedefiyle uyumlu: kullanıcıya yalnızca
sayı göstermek yerine, anlamlı ve eyleme dönük cümleler sunar.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date

from ..models import Transaction, TxType


def _month_key(d: date) -> tuple[int, int]:
    return (d.year, d.month)


def _prev_month(y: int, m: int) -> tuple[int, int]:
    return (y - 1, 12) if m == 1 else (y, m - 1)


def generate_insights(txs: list[Transaction], today: date | None = None) -> list[dict]:
    today = today or date.today()
    cur = (today.year, today.month)
    prev = _prev_month(*cur)

    exp_cur = defaultdict(float)
    exp_prev = defaultdict(float)
    income_cur = 0.0
    for t in txs:
        mk = _month_key(t.occurred_on)
        if t.type == TxType.expense:
            if mk == cur:
                exp_cur[t.category.value] += t.amount
            elif mk == prev:
                exp_prev[t.category.value] += t.amount
        elif t.type == TxType.income and mk == cur:
            income_cur += t.amount

    total_cur = sum(exp_cur.values())
    total_prev = sum(exp_prev.values())
    insights: list[dict] = []

    # 1) Bu ay vs geçen ay toplam
    if total_prev > 0:
        change = (total_cur - total_prev) / total_prev * 100
        if change >= 10:
            insights.append({
                "icon": "trending_up", "tone": "warn",
                "title": "Harcaman arttı",
                "text": f"Bu ay geçen aya göre %{abs(change):.0f} daha fazla harcadın.",
            })
        elif change <= -10:
            insights.append({
                "icon": "trending_down", "tone": "good",
                "title": "Harcaman azaldı",
                "text": f"Bu ay geçen aya göre %{abs(change):.0f} daha az harcadın. 👏",
            })

    # 2) En çok artan kategori
    biggest = None
    for cat, cur_val in exp_cur.items():
        prev_val = exp_prev.get(cat, 0.0)
        if prev_val > 0:
            diff = (cur_val - prev_val) / prev_val * 100
            if diff >= 25 and (biggest is None or diff > biggest[1]):
                biggest = (cat, diff)
    if biggest:
        insights.append({
            "icon": "category", "tone": "warn",
            "title": f"{biggest[0]} harcaman dikkat çekiyor",
            "text": f"{biggest[0]} kategorisine geçen aya göre %{biggest[1]:.0f} "
                    f"daha fazla harcadın.",
        })

    # 3) En çok harcanan kategori
    if exp_cur:
        top_cat = max(exp_cur.items(), key=lambda kv: kv[1])
        share = top_cat[1] / total_cur * 100 if total_cur else 0
        insights.append({
            "icon": "pie_chart", "tone": "neutral",
            "title": "En büyük harcama kalemin",
            "text": f"Bu ayki harcamanın %{share:.0f}'i {top_cat[0]} kategorisinde.",
        })

    # 4) Tasarruf oranı
    if income_cur > 0:
        saving = (income_cur - total_cur) / income_cur * 100
        if saving > 0:
            insights.append({
                "icon": "savings", "tone": "good",
                "title": "Tasarruf oranın",
                "text": f"Bu ay gelirinin %{saving:.0f}'ini biriktirdin.",
            })
        else:
            insights.append({
                "icon": "warning", "tone": "warn",
                "title": "Gelirini aştın",
                "text": "Bu ay gelirinden daha fazla harcadın. Bütçeni gözden geçir.",
            })

    if not insights:
        insights.append({
            "icon": "info", "tone": "neutral",
            "title": "Henüz yeterli veri yok",
            "text": "Birkaç işlem ekledikçe kişisel içgörüler burada görünecek.",
        })
    return insights
