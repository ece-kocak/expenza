# Expenza: eksikler ve yapılacaklar

Bu dosya, 3 Ekim 2026'da `b3397d7` commit'i üzerinde yapılan teknik analizden çıkan eksikleri tek yerde topluyor. Bir madde düzeltildiğinde kutusu işaretlenir ve yanına ilgili commit ya da PR yazılır.

| Öncelik | Anlamı |
|---|---|
| P0 | Projeyi çalıştırmayı ya da güvenliği ciddi şekilde etkiliyor. İlk bunlar yapılır. |
| P1 | Önemli güvenlik, işlev veya mimari sorunlar. |
| P2 | Teknik borç ve kod kalitesi. |
| P3 | Olsa iyi olur. |

Kimlik önekleri: `SEC` güvenlik, `HATA` işlev hatası, `ALT` altyapı ve belgeler, `KOD` kod kalitesi, `OZ` yeni özellik, `TEZ` bitirme projesi gereksinimi.

---

## P0

- [x] `SEC-01` JWT imza anahtarı için koda gömülü bir varsayılan değer var (`backend/app/auth.py:17`). Repo herkese açık olduğu için bu değer bilinen bir değer sayılmalı; onu bilen herkes istediği kullanıcı adına token üretebilir. Yapılacak: varsayılanı kaldırmak, `SECRET_KEY` tanımlı değilse backend'in hiç başlamaması.
- [x] `SEC-02` `/ml/categorize` kimlik doğrulamasız (`backend/app/routers/ml_router.py:14`). `GEMINI_API_KEY` tanımlıysa her istek ücretli bir Gemini çağrısı yapıyor. Yapılacak: `get_current_user` eklemek, metin uzunluğunu sınırlamak.
- [x] `ALT-01` Repoda README yok. Yapılacak: Python sürümü, ortam değişkenleri, port (8010), demo veri, backend ve Flutter çalıştırma adımları.
- [x] `ALT-02` Kod `.env` dosyasını okumuyor ve `.env.example` yok. `antigravity_docs` anahtarın `.env`'e yazılmasını söylüyor ama bu şu an etkisiz. Yapılacak: `SECRET_KEY`, `DATABASE_URL`, `GEMINI_API_KEY` için örnek dosya ve yükleme (`python-dotenv` zaten kurulu geliyor).
- [x] `ALT-03` `requirements.txt` scikit-learn sürümünü sabitlemiyor. Model 1.9.0 ile kaydedilmiş; 1.9.1 ile açılışta `InconsistentVersionWarning` görüldü, daha eski sürümlerde model yüklenemeyip sessizce kural tabanlı yedeğe düşebilir. Yapılacak: modelle aynı sürümü ve diğer paketleri sabitlemek.
- [x] `ALT-04` Migration yok, tablolar `create_all` ile oluşuyor (`backend/app/main.py:17`). Sonradan eklenen `is_recurring` sütunu eski veritabanlarında olmadığı için `/transactions` 500 döner. Yapılacak: Alembic kurmak, mevcut şemayı ilk migration olarak almak.

## P1

### İşlev hataları

- [x] `HATA-01` Tekrarlayan işlemler çift kayıt üretiyor (`backend/app/routers/transactions.py`, `_generate_recurring_transactions`). Üretilen kopyalar da `is_recurring=True` olduğu için kaynak gibi işleniyor. Ayın 29-31'inde başlayan seriler kısa aylardan sonra iki kez yazılıyor; notu ya da tutarı düzenlenen seriler yeni kopyalar üretiyor; silinen bir kopya bir sonraki listelemede geri geliyor. Düzeltildi: tekrarlayan işlemler artık `recurring_series` tablosunda birer seri; kopyalar serinin gününden üretiliyor (`app/recurring.py`, migration 0003).
- [x] `HATA-02` Aynı fonksiyon `GET /transactions` içinde çalışıyor, yani okuma isteği veritabanına yazıyor. Uygulama açılışta bu ucu aynı anda üç kez çağırıyor; benzersizlik kısıtı olmadığı için eşzamanlı isteklerde aynı kopya iki kez oluşabilir. Yapılacak: seriyi ayrı bir kayıt olarak modellemek, üretimi GET'ten çıkarmak, benzersizlik kısıtı eklemek. Düzeltildi: üretim GET'ten çıktı, açılışta ve saatte bir arka planda çalışıyor; `(series_id, occurred_on)` benzersiz. Eski kayıtlar migration'da serilere bağlandı, aynı güne düşen kopyalar silinmeden seriden ayrıldı.
- [x] `HATA-03` Ana sayfadaki bakiye sadece son 200 işlemden hesaplanıyor (`mobile/lib/screens/dashboard_screen.dart:79`, `115-120`; `api_client.dart:80`). Yapılacak: bakiye ve özetler için backend'de bir özet ucu. Düzeltildi: `GET /transactions/summary` eklendi. Ayrıca ana sayfadaki grafik başlığında ay adı yazdığı halde son 200 işlemin tamamını gösteriyordu; artık sadece bu ayı gösteriyor. Analitik ekranındaki "En Çok Harcanan Kategoriler" hâlâ son 200 işlemden hesaplanıyor (P2).
- [x] `HATA-04` Android release derlemesinde `INTERNET` izni yok (`mobile/android/app/src/main/AndroidManifest.xml`); izin sadece debug ve profile manifestlerinde. Release APK backend'e bağlanamaz. İzin eklendi. Bu makinede Android SDK olmadığı için APK ile denenmedi; yayındaki backend HTTPS değilse Android'in şifresiz HTTP kısıtı ayrıca kontrol edilmeli (belirsiz).
- [ ] `HATA-05` Kategori tahmini `gemini-1.5-flash` adını sabit kullanıyor (`backend/app/ml/categorizer.py:146`). Modelin hâlâ hizmette olup olmadığı belirsiz; değilse her öneri önce başarısız bir çağrı yapıp sonra yerel modele düşer. Yapılacak: model adlarını ayara taşımak (bkz. `TEZ-02`).

### Güvenlik

- [ ] `SEC-03` Giriş, kayıt, sohbet ve kategori uçlarında istek sınırı yok. Yapılacak: IP ve hesap bazlı limit, art arda başarısız girişte gecikme.
- [ ] `SEC-04` İstemci bütün istekleri şifresiz HTTP ile atıyor (`mobile/lib/api_client.dart:24-36`). Yapılacak: yayında HTTPS, API adresinin derleme sırasında verilmesi (`--dart-define`).
- [ ] `SEC-05` Sohbet; kullanıcı adını, son 30 işlemi (notlarla), bütçeleri ve hedefleri Gemini'ye gönderiyor (`backend/app/routers/chat.py:32-114`). Kategori tahmini de notu gönderiyor. Kullanıcıya bildirim ya da onay yok. Yapılacak: bilgilendirme ve açık rıza, gönderilen veriyi en aza indirmek, ayarlardan kapatılabilir yapmak.
- [ ] `SEC-06` CORS `allow_origins=["*"]` ile `allow_credentials=True` birlikte (`backend/app/main.py:26-32`). Starlette bu durumda istekteki origin'i yansıtıyor. Yapılacak: izinli adres listesi.
- [ ] `SEC-07` Sohbet hatalarında Gemini'nin cevabı ve istisna metni istemciye dönüyor (`backend/app/routers/chat.py:119-133`). Yapılacak: istemciye genel mesaj, ayrıntı sunucu loguna.
- [ ] `SEC-08` Gemini API anahtarı URL'de gidiyor (`chat.py:102`, `categorizer.py:146`). Yapılacak: istek başlığında göndermek.
- [ ] `SEC-10` Parola için tek kural "en az 6 karakter" (`backend/app/schemas.py:13`).
- [ ] `SEC-14` python-jose 3.3.0 kullanılıyor; CVE-2024-33663 ve CVE-2024-33664 bu sürümü etkiliyor (bugünkü HS256 kullanımında doğrudan sömürülebilir görünmüyor). Yapılacak: PyJWT'ye geçmek ve `pip-audit` çalıştırmak.
- [ ] `SEC-16` `/docs`, `/redoc` ve `/openapi.json` herkese açık. Yapılacak: yayında kapatmak ya da korumak.

### Altyapı

- [x] `ALT-05` Diğer kopyadaki (`themlie/expenza`) commit'lenmemiş çalışmalar bu repoya taşınmalı: fiş tarama (`ocr_service.dart`, `image_picker`, `google_mlkit_text_recognition`, iOS izinleri), `toggleThemeMode` düzeltmesi, README ve güncel yol haritası. Fiş tarama ve tema taşındı; fişten okunan TL tutarı artık seçili para birimine çevriliyor. Yol haritasının (`YOL_HARITASI.md`) taşınması ayrıca kararlaştırılacak.
- [x] `ALT-06` Repo temizliği: `backend/venv/` (8138 dosya, Mac'e ait Python 3.9 ortamı) ve `mobile/macos/Flutter/ephemeral/` git takibinden çıkarılmalı (`git rm --cached`). İkisi de geliştiricinin yerel yolunu içeriyor.
- [x] `ALT-07` Backend'de hiç test yok. Yapılacak: pytest ile kayıt ve giriş, token, başka kullanıcının kaydına erişim, işlem uçları, bütçe hesabı, tekrarlayan işlem ve analitik testleri. `backend/tests/` altında 60 test eklendi; kapsam %85 (`pytest --cov=app`). Tekrarlayan işlem testleri `HATA-01` ile gelecek.
- [x] `ALT-08` Tek widget testi başarısız (`mobile/test/widget_test.dart:9`): giriş ekranında iki "Giriş Yap" metni var, test bir tane bekliyor. Test düzeltildi ve kayıt sekmesi için ikinci test eklendi; bu test giriş ekranının altındaki satırın büyük yazı boyutunda taştığını da ortaya çıkardı (düzeltildi).
- [ ] `ALT-09` CI yok. Yapılacak: GitHub Actions ile her push'ta pytest, `flutter analyze` ve `flutter test`.
- [ ] `ALT-10` Fiş tarama (ML Kit) iOS'ta büyük olasılıkla en az iOS 15.5 hedefi istiyor; `ios/Podfile` repoda yok ve iOS derlemesi Mac olmadan denenemedi. Mac'te ilk `flutter run` sırasında kontrol edilmeli (belirsiz).

## P2

### İşlev hataları

- [ ] `HATA-06` Bütçe, hedef ve geçmiş ekranları istek başarısız olunca boş liste gösteriyor (`budgets_screen.dart:59`, `goals_screen.dart:80`, `history_screen.dart:217`).
- [ ] `HATA-07` Token süresi (7 gün) dolunca uygulama giriş ekranına dönmüyor; ekranlar hata gösteriyor.
- [x] `HATA-08` `PUT /transactions/{id}` ile bir alana `null` gönderilirse 500 dönüyor (`transactions.py:160-163`). Düzeltildi: `null` gönderilen alanlar artık değiştirilmiyor.
- [ ] `HATA-09` Analitik sekmesi işlem eklendikten sonra yenilenmiyor (`home_shell.dart:48`).
- [x] `HATA-10` Veritabanı yolu göreli (`backend/app/database.py:11`); backend başka klasörden başlatılırsa boş bir veritabanı oluşur.
- [x] `HATA-11` İşlemler listesinde gün başlığındaki net tutar eksi işaretini iki kez yazıyordu ("−−₺202,62"). Düzeltildi (`history_screen.dart`).

### Güvenlik

- [ ] `SEC-09` Token 7 gün geçerli, refresh yok, çıkış sadece istemcide (`auth.py:19`, `api_client.dart:66`).
- [ ] `SEC-11` Kayıt hatası e-postanın kayıtlı olduğunu söylüyor; girişte kullanıcı yoksa bcrypt çalışmadığı için cevap süresi farklı (`auth_router.py:16`, `33-38`).
- [ ] `SEC-12` Not, görünen ad, sohbet mesajı ve kategori metninde uzunluk sınırı yok; `limit` parametresi ve tutarlar için üst sınır yok.
- [ ] `SEC-13` Demo hesabın bilgileri giriş ekranına gömülü (`login_screen.dart:16-17`). Yapılacak: önceden doldurmayı sadece debug derlemesine bağlamak, `seed_demo.py`'nin yayında çalışmasını engellemek.
- [ ] `SEC-15` Model pickle formatında yükleniyor (`categorizer.py:107`). Yapılacak: model dosyasının hash'ini doğrulamak.
- [ ] `SEC-17` Android release derlemesi debug anahtarıyla imzalanıyor (`mobile/android/app/build.gradle.kts:32`).
- [ ] `SEC-18` Kullanıcı metni Gemini prompt'una doğrudan ekleniyor (`chat.py:79-110`, `categorizer.py:133-143`). Yapılacak: kullanıcı metnini ayrı ve sınırlı bir bölümde vermek.
- [ ] `SEC-20` Backend güvenlik başlığı eklemiyor (en azından `X-Content-Type-Options` ve HTTPS ile HSTS).
- [ ] `SEC-21` Güvenlik olayları (başarısız giriş, kayıt, silme) loglanmıyor; sadece birkaç `print` var.

### Kod kalitesi

- [ ] `KOD-01` Para `float` olarak saklanıyor (`models.py:66`). Kuruş cinsinden tam sayı ya da `Decimal` düşünülmeli.
- [ ] `KOD-02` Kategori listesi en az altı yerde ayrı tutuluyor (`CategoryEnum`, `KEYWORDS`, `generate_data.DATA`, `kCategories`, profil metni, renk/ikon eşlemeleri). `Toplam` bir kategori değil, `CategoryEnum`'dan ayrılmalı; şu an API onu işlem kategorisi olarak da kabul ediyor.
- [ ] `KOD-03` Ekran dosyaları 500-840 satır ve arayüz, API çağrısı ve iş kuralı aynı yerde. Backend'de iş kuralları router'larda; servis katmanı yok.
- [x] `KOD-04` Kullanılmayan bağımlılıklar: `pydantic-settings`, çalışma zamanında `pandas` (sadece eğitimde gerekli), `provider`. Kullanılmayan kod: `ExpenzaAppBar` (`home_shell.dart:102`). Not: `cupertino_icons` önce kaldırıldı, sonra geri eklendi; uygulama kodu kullanmasa da Flutter'ın Cupertino bileşenleri bu fonta ihtiyaç duyuyor.
- [ ] `KOD-05` Gemini çağrısı iki ayrı yerde ve iki farklı model adıyla yazılmış (`chat.py`, `categorizer.py`). Tek modülde toplanmalı.
- [ ] `KOD-06` Performans: tekrarlayan işlem üretimindeki N+1 sorgu ve satır başına commit; açılışta beş sekmenin birden yüklenmesi (3 kez `GET /transactions`); analitik uçlarının bütün işlemleri belleğe çekmesi; `chat.py`'de `async` fonksiyon içinde senkron veritabanı sorgusu; sayfalama olmaması.
- [ ] `KOD-07` Güncel olmayan belgeler: `expenza_yol_haritasi.md` Go, PostgreSQL ve Riverpod anlatıyor; `categorizer.py` başındaki açıklama "STUB ile çalışır" diyor.
- [ ] `KOD-08` `theme.dart:37` `\$e` yazdığı için döviz kuru hatasını basmıyor.
- [ ] `KOD-09` Backend metinleri (içgörü, anomali nedeni, sohbet) para birimini ₺ olarak sabit yazıyor. Geçmiş tutarlar bugünkü kurla çevriliyor.
- [x] `KOD-10` `categorizer.py`'de `Optional` import edilmemiş; sadece `from __future__ import annotations` sayesinde hata vermiyor.

## P3: yeni özellikler ve yarım kalanlar

- [ ] `OZ-01` Kalıcı oturum (güvenli depolama). Şu an token sadece bellekte.
- [ ] `OZ-02` İşlem tarihi seçici. Backend `occurred_on` alanını destekliyor, arayüzde yok.
- [ ] `OZ-03` Hedef son tarihi ve hedef düzenleme. Backend `deadline` alanını destekliyor, arayüzde yok.
- [ ] `OZ-04` Sohbette Markdown gösterimi (şu an `**` gibi işaretler görünüyor) ve konuşma geçmişi.
- [ ] `OZ-05` Şifre sıfırlama (şu an "yakında"), şifre değiştirme, hesap silme.
- [ ] `OZ-06` Bütçe aşımı ve anomali için gerçek bildirim. Profildeki bildirim anahtarı şu an sadece görsel.
- [ ] `OZ-07` PDF ve CSV dışa aktarma.
- [x] `OZ-08` Tekrarlayan işlem arayüzü: gider için de seçilebilmesi, seriyi durdurma, ne yaptığını anlatan bir etiket ("Gelir kaydedilsin mi" yerine). Yapıldı: kutu giderde de görünüyor, etiketi "Her ay tekrarla"; işaret kaldırılınca seri duruyor, tutar/not düzenlemesi sonraki aylara geçiyor.
- [ ] `OZ-09` Arayüzde ay filtresi ve sayfalama.
- [ ] `OZ-10` Profildeki sabit öğeler: "Premium üye" etiketi, sürüm numarası, işlevsiz ayarlar ikonu.

---

## Bitirme projesi açısından eksikler

BLM497 şablonları (Proje Önerisi, Gereksinimler Şartnamesi ve Ön Analiz, Ön Tasarım) ile tezin ana iddiası ("aktif finans koçu plansız harcamayı azaltır") esas alınarak çıkarıldı.

- [ ] `TEZ-01` (P0) Ana iddiayı ölçen bir deney tasarımı yok. Karar verilmeli: gerçek kullanıcılarla pilot (örneğin 2-4 hafta, ön ve son anket, SUS kullanılabilirlik ölçeği, kullanım metrikleri) ya da simülasyon. Bu karar kayıt tutulacak verileri ve onay metnini belirlediği için erken verilmeli.
- [ ] `TEZ-02` (P1) Kendi eğitilen model ürünün ana yolu değil. `GEMINI_API_KEY` tanımlıysa kategori önerisini önce Gemini veriyor, kendi model yedek konumuna düşüyor. Yapılacak: kendi model ana yol olmalı; Gemini aynı doğrulama setinde kıyas modeli olarak değerlendirilebilir.
- [ ] `TEZ-03` (P1) Doğrulama seti 46 örnek. `MODEL_RESULTS.md` de 150+ gerçek örnek öneriyor. Sınıf bazında precision ve recall, karışıklık matrisi, gecikme ve model boyutu kıyası eklenmeli.
- [ ] `TEZ-04` (P1) Kullanıcının öneriyi kabul ya da reddetmesi kaydedilmiyor. Kaydedilirse modelin gerçek kullanımdaki doğruluğu ölçülebilir ve yeniden eğitimde kullanılabilir.
- [ ] `TEZ-05` (P2) Tahmin ve anomali yöntemleri ölçülmemiş. Geçmiş veride geriye dönük test (MAE, MAPE) ve eklenen anomalilerle precision/recall yapılabilir.
- [ ] `TEZ-06` (P1) GŞÖA için UML çizimleri: use case, sınıf, sıra, durum makinesi, etkinlik.
- [ ] `TEZ-07` (P1) ÖT için modül, veri ve arayüz ayrıştırması (arayüzler OpenAPI şemasından çıkarılabilir).
- [ ] `TEZ-08` (P1) İşlevsel olmayan gereksinimler için ölçülmüş değerler: kapasite, güvenilirlik, ölçeklenebilirlik (yük testi). GŞÖA'nın sürdürülebilirlik bölümü CI'ın nasıl kullanıldığını soruyor (`ALT-09`).
- [ ] `TEZ-09` (P2) "Aktif koç" iddiasını destekleyen proaktif özellikler az: bildirim (`OZ-06`), bütçe kaydırma önerisi, risk skoru, "farz et ki" senaryosu.
- [ ] `TEZ-10` (P2) Test bölümü için test sonuçları ve kapsam (coverage) raporu (`ALT-07`, `ALT-08`).
- [ ] `TEZ-11` (P1) Jüri demosu için kararlı bir ortam: HTTPS'li bir sunucu ya da yerel demo için yazılı bir yedek plan.
- [ ] `TEZ-12` (P1) Pilotta gerçek finans verisi toplanacaksa aydınlatma metni ve açık rıza gerekir. Etik kurul onayı gerekip gerekmediği danışmana sorulmalı.
