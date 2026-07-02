"""Demo verisi üretici — tahmin ve anomali özelliklerini göstermek için.

Test kullanıcısı (test@expenza.com) için son ~4 ayın gerçekçi harcamalarını ekler;
ayrıca birkaç kasıtlı 'olağandışı' (yüksek) harcama enjekte eder. Böylece Analitik
ekranındaki tahmin ve anomali bölümleri demo'da dolu görünür.

Çalıştırma:
    python seed_demo.py
"""
import random
from datetime import date, timedelta

from app.auth import hash_password
from app.database import SessionLocal
from app.models import CategoryEnum, Transaction, TxType, User

random.seed(7)

# Kategori başına tipik harcama aralığı (gerçekçi gündelik tutarlar)
TYPICAL = {
    CategoryEnum.yemek: (40, 180),
    CategoryEnum.ulasim: (20, 90),
    CategoryEnum.faturalar: (150, 600),
    CategoryEnum.eglence: (50, 250),
    CategoryEnum.saglik: (60, 300),
    CategoryEnum.egitim: (80, 400),
    CategoryEnum.alisveris: (100, 700),
}
NOTES = {
    CategoryEnum.yemek: ["migros", "yemeksepeti", "kahve", "market", "öğle yemeği"],
    CategoryEnum.ulasim: ["uber", "benzin", "metro", "otobüs bileti"],
    CategoryEnum.faturalar: ["elektrik faturası", "internet", "kira", "doğalgaz"],
    CategoryEnum.eglence: ["netflix", "sinema", "konser", "spotify"],
    CategoryEnum.saglik: ["eczane", "doktor", "diş hekimi"],
    CategoryEnum.egitim: ["kitap", "online kurs", "kırtasiye"],
    CategoryEnum.alisveris: ["trendyol", "zara", "teknosa", "ayakkabı"],
}


def get_or_create_user(db) -> User:
    user = db.query(User).filter(User.email == "test@expenza.com").first()
    if not user:
        user = User(
            email="test@expenza.com",
            hashed_password=hash_password("secret1"),
            display_name="Sena",
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def main() -> None:
    db = SessionLocal()
    try:
        user = get_or_create_user(db)

        # Önce bu kullanıcının mevcut işlemlerini temizle (tekrar çalıştırılabilir olsun)
        db.query(Transaction).filter(Transaction.user_id == user.id).delete()
        db.commit()

        today = date.today()
        rows: list[Transaction] = []

        # Son 4 ay (bu ay dahil) için günlük rastgele harcamalar
        for days_ago in range(0, 120):
            d = today - timedelta(days=days_ago)
            # Günde 0-3 harcama
            for _ in range(random.randint(0, 3)):
                cat = random.choice(list(TYPICAL.keys()))
                lo, hi = TYPICAL[cat]
                amount = round(random.uniform(lo, hi), 2)
                rows.append(Transaction(
                    user_id=user.id, amount=amount, type=TxType.expense,
                    category=cat, auto_categorized=True,
                    note=random.choice(NOTES[cat]), occurred_on=d,
                ))

        # Aylık gelir
        for m in range(0, 4):
            d = today.replace(day=1) - timedelta(days=30 * m)
            rows.append(Transaction(
                user_id=user.id, amount=12000, type=TxType.income,
                category=CategoryEnum.diger, note="Maaş", occurred_on=d,
            ))

        # Kasıtlı anomaliler (olağandışı yüksek harcamalar) — bu ay içinde
        rows.append(Transaction(
            user_id=user.id, amount=4500, type=TxType.expense,
            category=CategoryEnum.alisveris, auto_categorized=False,
            note="Laptop", occurred_on=today - timedelta(days=3),
        ))
        rows.append(Transaction(
            user_id=user.id, amount=1800, type=TxType.expense,
            category=CategoryEnum.yemek, auto_categorized=False,
            note="Doğum günü yemeği", occurred_on=today - timedelta(days=6),
        ))

        db.add_all(rows)
        db.commit()
        print(f"{len(rows)} işlem eklendi (kullanıcı: {user.email}).")
    finally:
        db.close()


if __name__ == "__main__":
    main()
