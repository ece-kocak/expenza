"""Sentetik Türkçe harcama verisi üretici (hero model eğitimi için).

Colab'da doğrulanan üretici ile aynı mantık; repoda kalıcı ve tekrar üretilebilir.
Çıktı: data/expenza_data.csv  (text, label)

Çalıştırma:
    python -m ml_training.generate_data
"""
import csv
import os
import random

random.seed(42)

# Her kategori için gerçekçi marka/anahtar kelimeler.
# Türkiye'nin yaygın markaları ve gerçek harcama ifadeleriyle genişletildi.
DATA: dict[str, list[str]] = {
    "Yemek": [
        # Marketler
        "migros", "bim", "a101", "şok", "carrefour", "macrocenter", "file market",
        "onur market", "hakmar", "tarım kredi market",
        # Sipariş / zincir
        "yemeksepeti", "getir", "getir yemek", "trendyol yemek", "banabi",
        "starbucks", "kahve dünyası", "espressolab", "gloria jeans", "caffè nero",
        "domino's", "pizza hut", "little caesars", "burger king", "mcdonalds",
        "kfc", "popeyes", "usta dönerci", "baydöner", "köfteci yusuf", "komagene",
        "subway", "by burger",
        # Yemek/ürün
        "lokanta", "restoran", "döner", "dürüm", "lahmacun", "pide", "pizza",
        "hamburger", "köfte", "çiğ köfte", "tost", "sandviç", "börek", "menemen",
        "çay", "kahve", "su", "ekmek", "süt", "peynir", "meyve sebze",
        "kahvaltı", "öğle yemeği", "akşam yemeği", "market alışverişi", "market",
        "bakkal", "manav", "kasap", "fırın", "pastane", "şarküteri",
    ],
    "Ulaşım": [
        "uber", "bitaksi", "marti", "hop", "binbin", "taksi",
        "iett", "metro", "metrobüs", "tramvay", "dolmuş", "minibüs",
        "otobüs bileti", "vapur", "feribot", "şehir hatları",
        "tcdd", "hızlı tren", "yht", "tren bileti",
        "uçak bileti", "pegasus", "türk hava yolları", "anadolujet", "sunexpress",
        "benzin", "motorin", "mazot", "akaryakıt", "lpg", "yakıt",
        "opet", "shell", "bp", "petrol ofisi", "total", "aytemiz",
        "otopark", "ispark", "otoyol", "köprü geçiş", "hgs", "ogs", "servis ücreti",
        "istanbulkart", "ulaşım kart dolum", "araç kiralama",
    ],
    "Faturalar": [
        "elektrik faturası", "su faturası", "doğalgaz faturası", "doğalgaz",
        "igdaş", "bedaş", "iski", "internet faturası", "fiber internet",
        "telefon faturası", "cep telefonu faturası", "hat faturası",
        "turkcell", "vodafone", "türk telekom", "türknet", "superonline",
        "d-smart", "digiturk", "beinconnect", "tivibu",
        "kira", "kira ödemesi", "aidat", "apartman aidatı", "site aidatı",
        "dask", "kasko", "trafik sigortası", "konut sigortası",
        "mtv", "vergi ödemesi", "otomatik ödeme talimatı",
    ],
    "Eğlence": [
        "sinema bileti", "sinema", "cinemaximum", "paribu cineverse",
        "netflix", "spotify", "youtube premium", "disney plus", "amazon prime",
        "exxen", "blutv", "gain", "mubi", "deezer", "apple music",
        "playstation plus", "xbox game pass", "steam", "epic games", "oyun",
        "konser bileti", "konser", "festival", "tiyatro", "opera", "müze", "sergi",
        "bar", "pub", "gece kulübü", "meyhane", "bowling", "bilardo", "langırt",
        "halı saha", "paintball", "lunapark", "eğlence parkı", "parti",
    ],
    "Sağlık": [
        "eczane", "ilaç", "hastane", "özel hastane", "poliklinik", "klinik",
        "doktor muayene", "muayene ücreti", "diş hekimi", "diş dolgusu",
        "ortodonti", "diş teli", "göz doktoru", "optik", "gözlük", "lens",
        "psikolog", "psikiyatr", "terapi seansı", "fizik tedavi",
        "kan tahlili", "tahlil", "röntgen", "mr çekimi", "ultrason",
        "ameliyat", "aşı", "vitamin", "takviye", "ağrı kesici", "antibiyotik",
        "maske", "termometre", "tansiyon aleti", "diyetisyen",
    ],
    "Eğitim": [
        "kitap", "ders kitabı", "roman", "kırtasiye", "defter", "kalem",
        "fotokopi", "çıktı", "okul taksiti", "özel okul", "kreş ücreti",
        "yurt ücreti", "kurs ücreti", "dershane", "etüt merkezi", "özel ders",
        "dil kursu", "ingilizce kursu", "almanca kursu",
        "udemy", "coursera", "online kurs",
        "yks kitabı", "tyt deneme", "ayt deneme", "kpss kitabı", "deneme sınavı",
        "sınav ücreti", "sertifika programı", "seminer", "atölye ücreti",
    ],
    "Alışveriş": [
        "trendyol", "hepsiburada", "amazon", "n11", "çiçeksepeti",
        "boyner", "beymen", "network", "zara", "mango", "bershka", "stradivarius",
        "h&m", "lc waikiki", "koton", "defacto", "mavi", "colins", "us polo",
        "ayakkabı", "flo", "deichmann", "nike", "adidas", "puma", "sneaker",
        "çanta", "giyim", "tişört", "pantolon", "elbise", "ceket", "mont",
        "teknosa", "mediamarkt", "vatan bilgisayar", "telefon", "laptop",
        "kulaklık", "elektronik", "kozmetik", "parfüm", "gratis", "watsons",
        "rossmann", "sephora", "saat", "takı", "ikea", "koçtaş", "ev tekstili",
    ],
    "Diğer": [
        "hediye", "doğum günü hediyesi", "bağış", "yardım derneği",
        "kuaför", "berber", "güzellik salonu", "manikür", "pedikür",
        "çamaşırhane", "kuru temizleme", "nalbur", "hırdavat", "çilingir",
        "noter", "avukat ücreti", "kargo", "ptt", "mng kargo", "yurtiçi kargo",
        "aras kargo", "banka masrafı", "havale ücreti", "komisyon", "abonelik",
        "spor salonu", "fitness üyeliği", "pilates", "yoga", "yüzme",
        "köpek maması", "kedi maması", "veteriner", "petshop",
        "çiçekçi", "oto yıkama", "oto tamir", "yedek parça",
    ],
}

# Gerçek kullanıcıların yazdığı tarzda çeşitlendirilmiş şablonlar.
TEMPLATES = [
    "{k}", "{k}", "{k}", "{k} aldım", "{k} ödemesi", "{k} için harcama",
    "{k} - nakit", "{k} kredi kartı", "bugün {k}", "dün {k}", "{k} masrafı",
    "aylık {k}", "{k} ödedim", "{k}ye gittim", "{k} parası", "{k} harcaması",
]

PER_CLASS = 800


def generate() -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for kategori, kelimeler in DATA.items():
        for _ in range(PER_CLASS):
            k = random.choice(kelimeler)
            metin = random.choice(TEMPLATES).format(k=k)
            rows.append((metin, kategori))
    random.shuffle(rows)
    return rows


def main() -> None:
    here = os.path.dirname(__file__)
    out_dir = os.path.join(here, "data")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "expenza_data.csv")

    rows = generate()
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["text", "label"])
        w.writerows(rows)

    print(f"{len(rows)} satır yazıldı -> {out_path}")


if __name__ == "__main__":
    main()
