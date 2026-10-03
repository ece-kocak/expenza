# Expenza

Expenza, harcamaları kendi eğittiğimiz Türkçe metin sınıflandırma modeliyle otomatik kategorize eden, bütçe, tasarruf hedefi, harcama tahmini ve olağandışı harcama uyarısı sunan bir kişisel finans uygulaması. Mobil ve web istemcisi Flutter ile, backend FastAPI ile yazıldı. Bilgisayar mühendisliği bitirme projesidir.

## Mimari

```
Flutter (mobile/)  --REST/JSON-->  FastAPI (backend/)  -->  SQLite (backend/expenza.db)
                                        |
                                        +--> Kategori modeli (backend/app/ml/, TF-IDF + SVM)
                                        +--> Google Gemini API (isteğe bağlı)
```

Bilinen eksikler ve yapılacaklar listesi [EKSIKLER.md](EKSIKLER.md) dosyasında. Model deneyleri ve sonuçları [backend/ml_training/MODEL_RESULTS.md](backend/ml_training/MODEL_RESULTS.md) dosyasında.

## Gereksinimler

- Python 3.12. `requirements.txt`'teki sürümler bununla test edildi; scikit-learn 1.9 Python 3.9 gibi eski sürümlere kurulmuyor.
- Flutter SDK (Dart 3.12 veya üstü).

## Backend'i çalıştırma

Windows (PowerShell):

```powershell
cd backend
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
```

macOS / Linux:

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Ardından `backend/.env` dosyasındaki `SECRET_KEY` satırını doldurun. Rastgele bir değer üretmek için:

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

`SECRET_KEY` boşsa ya da 32 karakterden kısaysa backend açılmaz. Sonra sunucuyu başlatın:

```bash
uvicorn app.main:app --reload --port 8010
```

- API: http://localhost:8010
- Etkileşimli API belgesi (Swagger): http://localhost:8010/docs
- Veritabanı şeması açılışta otomatik olarak son migration'a getirilir. Migration'lardan önce oluşturulmuş eski `expenza.db` dosyaları da tanınır ve verileri korunarak güncellenir.

Port 8010 seçildi çünkü geliştirme makinesinde 8000 başka bir süreç tarafından kullanılıyordu. Portu değiştirirseniz `mobile/lib/api_client.dart` içindeki `ApiClient.port` değerini de değiştirin.

### Ortam değişkenleri

Değerler ortam değişkenlerinden ya da `backend/.env` dosyasından okunur; ikisi birden varsa ortam değişkeni geçerli olur.

| Değişken | Zorunlu | Açıklama |
|---|---|---|
| `SECRET_KEY` | Evet | JWT imza anahtarı, en az 32 karakter |
| `DATABASE_URL` | Hayır | Boşsa `backend/expenza.db` (SQLite) kullanılır |
| `GEMINI_API_KEY` | Hayır | Tanımlıysa sohbet asistanı açılır |
| `GEMINI_CHAT_MODEL` | Hayır | Sohbet modeli, varsayılan `gemini-2.5-flash` |
| `CATEGORIZER` | Hayır | `local` (varsayılan, projede eğitilen model) ya da `gemini` (kıyas için) |
| `GEMINI_CATEGORIZER_MODEL` | Hayır | `CATEGORIZER=gemini` iken kullanılan model |
| `CORS_ORIGINS` | Hayır | Web istemcisinin yayınlandığı adresler, virgülle ayrılmış. localhost'un bütün portlarına zaten izin verilir. |
| `DOCS_ENABLED` | Hayır | `false` yapılırsa `/docs`, `/redoc` ve `/openapi.json` kapanır (yayında önerilir) |

Giriş, kayıt, sohbet ve kategori uçlarında istek sınırı vardır (örneğin aynı e-postayla 15 dakikada 5 hatalı parola denemesinden sonra 429 döner). Sınırlayıcı bellek içinde çalışır, yani tek sunucu süreci için tasarlanmıştır. Yeni hesaplarda parola en az 8 karakter olmalı ve en az bir harf ile bir rakam içermelidir.

Sohbet asistanı kullanıcı uygulamada açık onay verene kadar çalışmaz. Onaydan sonra her soruda kullanıcının son 30 işlemi, bütçeleri ve hedefleri Google'a gönderilir; adı ve e-postası gönderilmez. Onay Profil > Ayarlar'dan geri çekilebilir. Kategori önerisi varsayılan olarak yerel modelden gelir ve Google'a veri göndermez.

### Demo verisi

```bash
python seed_demo.py
```

Bir demo kullanıcısı ve yaklaşık dört aylık örnek işlem oluşturur; giriş ekranı bu hesapla dolu gelir. Betik her çalıştırıldığında demo kullanıcısının mevcut işlemlerini silip yeniden yazar.

## Flutter uygulamasını çalıştırma

```bash
cd mobile
flutter pub get
flutter run -d chrome
```

- Web ve iOS simülatöründe uygulama `localhost:8010` adresine bağlanır.
- Android emülatöründe `10.0.2.2:8010` kullanılır (emülatörden bilgisayara köprü adresi).
- Bağlı bir telefon ya da emülatör için `-d chrome` olmadan `flutter run` yeterlidir.

Yayın derlemesinde backend adresi derleme sırasında verilir; adres HTTPS olmalıdır:

```bash
flutter build web --dart-define=API_BASE_URL=https://api.ornek.com
```

## Testler

Backend testleri geçici bir SQLite veritabanı kullanır ve Gemini'ye istek atmaz:

```bash
cd backend
pip install -r requirements-dev.txt
pytest --cov=app
```

Flutter tarafında:

```bash
cd mobile
flutter analyze
flutter test
```

Aynı kontroller her push'ta GitHub Actions ile çalışır (`.github/workflows/ci.yml`).

## Veritabanı değişiklikleri (migration)

Şema Alembic ile yönetilir; migration dosyaları `backend/migrations/versions/` altında. Bir modele alan eklediğinizde `backend` klasöründe:

```bash
alembic revision --autogenerate -m "kısa açıklama"
```

Oluşan dosyayı kontrol edin, sonra `alembic upgrade head` çalıştırın ya da backend'i yeniden başlatın. `alembic check` komutu modellerle migration'ların uyumlu olup olmadığını söyler.

## Model eğitimi

```bash
cd backend
pip install -r requirements-ml.txt
python -m ml_training.generate_data
python -m ml_training.train_baseline
python -m ml_training.evaluate
```

Üründe kullanılan model `backend/app/ml/model/categorizer.joblib` dosyasıdır ve scikit-learn 1.9.0 ile kaydedilmiştir. scikit-learn sürümü değişirse model yeniden eğitilmelidir. BERTurk kıyas modeli (`ml_training/berturk_train.py`) GPU ister; kurulumu `requirements-ml.txt` içinde açıklanıyor.
