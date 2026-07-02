# Expenza — Flutter Geliştirme Yol Haritası

## Teknoloji Kararı: Neden Flutter?

Tez önerisinde iOS için Swift, Android için Go yazılmış olsa da **Flutter** kullanımı bu hedefleri daha verimli karşılar:
- Tek kod tabanından hem iOS hem Android çıktısı → geliştirme süresi yarıya iner
- `fl_chart` paketiyle pasta/çubuk/çizgi grafik desteği hazır gelir
- Material Design & Cupertino widget'ları ile koyu tema ve yüksek kontrast arayüz kolayca uygulanır
- Tez savunmasında "cross-platform geliştirme" kararını metodoloji bölümünde gerekçelendirmek yeterli

---

## Önerilen Mimari: Clean Architecture

```
lib/
├── core/            # Sabitler, renkler, tema, yardımcı fonksiyonlar
├── data/            # API katmanı, local DB (SQLite/Hive), modeller
├── domain/          # İş mantığı, entity'ler, use case'ler
├── presentation/    # Ekranlar (screens) ve widget'lar
└── main.dart
```

**State Management:** `Riverpod` (veya `BLoC`) — tez için ikisi de savunulabilir  
**Local Storage:** `Hive` veya `sqflite` — offline çalışma için  
**HTTP:** `Dio` — JWT interceptor desteğiyle  
**Grafikler:** `fl_chart`  
**Navigasyon:** `GoRouter`

---

## Backend (Ayrı Repo)

| Katman | Teknoloji |
|--------|-----------|
| API | Go (Fiber/Echo) veya Node.js (Fastify) |
| Veritabanı | PostgreSQL |
| Auth | JWT (Access + Refresh Token) |
| Protokol | HTTPS / RESTful |
| Deployment | Docker + Railway/Render (ücretsiz tier) |

---

## FAZ 1 — Altyapı & Proje Kurulumu (Hafta 1–2)

### Hedef
Geliştirme ortamı hazır, boş ama çalışan uygulama ayağa kalkmış olacak.

### Yapılacaklar

**Flutter tarafı**
- [ ] `flutter create expenza` ile proje oluştur
- [ ] Klasör yapısını (Clean Architecture) kur
- [ ] `pubspec.yaml`'a paketleri ekle: `flutter_riverpod`, `dio`, `hive_flutter`, `fl_chart`, `go_router`, `intl`, `flutter_secure_storage`
- [ ] Tema dosyasını oluştur: koyu tema, renk paleti, font (Inter veya Poppins)
- [ ] Splash screen & uygulama ikonunu ayarla

**Backend tarafı**
- [ ] Go projesi başlat, klasör yapısını kur (`/routes`, `/handlers`, `/models`, `/middleware`)
- [ ] PostgreSQL bağlantısını kur (GORM veya pgx)
- [ ] Veritabanı şemasını oluştur (aşağıya bak)
- [ ] Docker Compose ile lokal ortamı ayağa kaldır

**Veritabanı Şeması (temel tablolar)**
```sql
users        (id UUID, email, password_hash, name, created_at)
categories   (id UUID, user_id, name, icon, color, type: income/expense)
transactions (id UUID, user_id, category_id, amount, note, date, created_at)
budgets      (id UUID, user_id, category_id, limit_amount, month, year)
goals        (id UUID, user_id, name, target_amount, saved_amount, deadline)
```

---

## FAZ 2 — Kimlik Doğrulama Ekranları (Hafta 3)

### Yapılacaklar
- [ ] **Kayıt ekranı:** ad, e-posta, şifre formu + validasyon
- [ ] **Giriş ekranı:** e-posta & şifre, hata mesajları
- [ ] JWT token'ı `flutter_secure_storage`'da güvenli sakla
- [ ] Token expire olduğunda otomatik refresh token mekanizması
- [ ] Auth guard: giriş yapılmamışsa login'e yönlendir

**Backend endpoint'leri**
```
POST /auth/register
POST /auth/login
POST /auth/refresh
```

---

## FAZ 3 — Ana Modüller: Gelir & Gider Girişi (Hafta 4–5)

### Yapılacaklar

**Hızlı İşlem Formu (tezin en kritik modülü — "manuel giriş disiplini")**
- [ ] Tutar girişi (custom numpad veya standart)
- [ ] Kategori seçimi (grid görünümü, ikonlar)
- [ ] Tarih seçici
- [ ] Not alanı (opsiyonel)
- [ ] Kaydet → anlık bütçe limiti kontrolü → uyarı veya onay

**Kategori Yönetimi**
- [ ] Varsayılan kategoriler: Yiyecek, Ulaşım, Eğlence, Faturalar, Sağlık, Eğitim, Diğer
- [ ] Kullanıcı özel kategori ekleyebilsin (renk + ikon seçimi)

**Son İşlemler Listesi**
- [ ] Tarihe göre gruplu liste (bugün, dün, bu hafta)
- [ ] Kaydırarak sil / düzenle (swipe actions)
- [ ] Arama + filtre (kategori, tarih aralığı)

**Backend endpoint'leri**
```
GET  /transactions?month=&year=
POST /transactions
PUT  /transactions/:id
DEL  /transactions/:id
GET  /categories
POST /categories
```

---

## FAZ 4 — Dashboard & Finansal Temeller Ekranı (Hafta 6)

### Yapılacaklar
- [ ] Aylık gelir / gider / net bakiye özet kartları
- [ ] Halka grafik (fl_chart `PieChart`): kategori bazlı gider dağılımı
- [ ] Gelir kaynakları listesi
- [ ] 6 aylık birikim öngörü hesaplaması (tasarruf oranı × kalan ay)
- [ ] Ay seçici (geçmiş aylara gezinti)

---

## FAZ 5 — Bütçe Limitleri & Hedefler (Hafta 7)

### Yapılacaklar

**Bütçe Yönetimi**
- [ ] Kategorilere aylık limit tanımlama
- [ ] Limit doluluk çubuğu (ProgressBar): yeşil → sarı → kırmızı
- [ ] Limit %80'ini aşınca push notification veya in-app banner uyarısı
- [ ] Limit aşımında işlem kaydederken kullanıcıyı uyar

**Tasarruf Hedefleri**
- [ ] Hedef adı, tutar, son tarih
- [ ] Her ay ne kadar ayırması gerektiğini hesapla
- [ ] Hedef ilerleme çubuğu
- [ ] Hedefe para aktar (balance'dan düşür)

**Backend endpoint'leri**
```
GET  /budgets?month=&year=
POST /budgets
GET  /goals
POST /goals
PUT  /goals/:id/deposit
```

---

## FAZ 6 — Analitik Panel (Hafta 8–9)

### Yapılacaklar

**Grafikler**
- [ ] Çizgi grafik: 6 aylık gelir vs. gider trendi (`LineChart`)
- [ ] Çubuk grafik: haftalık harcama dağılımı (`BarChart`)
- [ ] Harcama hızı: günlük ortalama × kalan gün = tahmini ay sonu tutarı

**Risk Skoru (tezin özgün katkısı)**
- [ ] Algoritma: `(toplam_gider / toplam_gelir) × 100` → 0-100 risk puanı
- [ ] Puan bandına göre renk: 0-40 yeşil, 40-70 sarı, 70+ kırmızı
- [ ] Risk puanı nedenleri (en yüksek 3 kategori) listele

**Gelecek Ay Tahmini**
- [ ] Son 3 ayın ortalamasına dayalı basit projeksiyon
- [ ] Tahmini açık var mı? → "Senaryoyu Çalıştır" butonu

---

## FAZ 7 — Senaryo Planlama / "Farz Et Ki" Modülü (Hafta 10)

### Yapılacaklar
- [ ] "Farz et ki X TL daha harcasaydım" simülatörü
- [ ] Gider/gelir değişkenini kaydırıcıyla (slider) ayarla
- [ ] Tahmini ay sonu bakiyesini anlık güncelle
- [ ] Simülasyon sonucunu kaydet → bütçe hedefi olarak sisteme ekle
- [ ] Kritik erken uyarı: nakit ömrü hesabı (bakiye / günlük ortalama harcama)

---

## FAZ 8 — Davranışsal Harcama Haritası & Dışa Aktarım (Hafta 11)

### Yapılacaklar

**Harcama Yoğunluk Haritası**
- [ ] Saate göre işlem yoğunluğu (heat map benzeri görsel)
- [ ] En çok harcama yapılan saat aralığını tespit et
- [ ] Hafta içi vs. hafta sonu karşılaştırması

**Dışa Aktarım**
- [ ] PDF raporu: `pdf` paketi ile aylık özet
- [ ] CSV/Excel: `excel` paketi ile tüm işlemler
- [ ] Paylaşım: `share_plus` paketi

---

## FAZ 9 — Test, Güvenlik & UX Cilaları (Hafta 12–13)

### Yapılacaklar

**Test**
- [ ] Unit testler: risk skoru algoritması, projeksiyon hesaplamaları
- [ ] Widget testleri: form validasyonları
- [ ] Integration test: login → giriş kaydet → dashboard akışı
- [ ] Farklı ekran boyutlarında test (küçük telefon, tablet)

**Güvenlik**
- [ ] HTTPS zorunlu (http trafiği engelle)
- [ ] Token'lar secure storage'da (plain shared prefs değil)
- [ ] SQL injection: parametrik sorgular (ORM kullanımı)
- [ ] Rate limiting backend'de

**UX**
- [ ] Boş durum ekranları (ilk kez açan kullanıcı için onboarding)
- [ ] Yükleme skeleton'ları (shimmer effect)
- [ ] Hata ekranları: internet yok, sunucu hatası

---

## FAZ 10 — Pilot Test & Hipotez Ölçümü (Hafta 14–15)

### Yapılacaklar
- [ ] 20-30 üniversite öğrencisine beta dağıt (TestFlight / Firebase App Distribution)
- [ ] Başlangıç anketi: finansal okuryazarlık ölçeği (5'li Likert)
- [ ] 4 hafta kullanım → bitiş anketi: aynı ölçek + memnuniyet soruları
- [ ] H1 hipotezi için bağımlı örneklem t-testi (paired t-test) uygula
- [ ] Kontrol grubu (uygulama kullanmayan) ile karşılaştır
- [ ] Bağımsız değişken: Expenza kullanımı (evet/hayır)
- [ ] Bağımlı değişkenler: finansal okuryazarlık puanı, aylık plansız harcama oranı

---

## FAZ 11 — Tez Yazımı & Sunum (Hafta 16–18)

### Yapılacaklar
- [ ] Metodoloji bölümünü Flutter kararıyla güncelle
- [ ] Ekran görüntüleri ve UX akışını teze ekle
- [ ] İstatistiksel bulguları (t-testi sonuçları) yorumla
- [ ] Sistem mimarisi diyagramını güncelle
- [ ] Sınırlılıklar ve gelecek çalışmalar bölümünü yaz
- [ ] Sunum hazırla (pptx)

---

## Haftalık Özet Takvim

| Hafta | Faz | Çıktı |
|-------|-----|-------|
| 1–2 | Altyapı Kurulumu | Çalışan proje iskeleti, DB şeması |
| 3 | Auth Ekranları | Login/Register + JWT |
| 4–5 | Gelir & Gider Girişi | Temel CRUD modülü |
| 6 | Dashboard | Özet kartlar + pasta grafik |
| 7 | Bütçe & Hedefler | Limit uyarıları, hedef takibi |
| 8–9 | Analitik Panel | Grafikler, risk skoru, projeksiyon |
| 10 | Senaryo Planlama | Simülatör modülü |
| 11 | Harita & Export | Harcama haritası, PDF/CSV |
| 12–13 | Test & Cila | Güvenlik, UX, edge case'ler |
| 14–15 | Pilot Test | Kullanıcı testleri, anket, istatistik |
| 16–18 | Tez & Sunum | Yazım, savunma |

---

## Başlarken İlk 3 Adım

1. `flutter create expenza --org com.sena.expenza` → projeyi oluştur
2. `pubspec.yaml`'a paketleri ekle, `flutter pub get` çalıştır
3. Backend için ayrı bir repo aç, Go veya Node ile `/auth/register` endpoint'ini yaz ve Postman'den test et

Bu temel çalışınca her şey üstüne oturur.
