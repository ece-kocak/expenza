# Değişiklikler ve Doğrulama Raporu (Walkthrough)

Bu raporda, Expenza uygulamasında yapılan hata düzeltmeleri, Gemini AI Asistan entegrasyonu ve son talep edilen geliştirmelerin teknik detayları özetlenmektedir.

## Yapılan Değişiklikler

### 1. Son Eklenen Özellikler ve Düzeltmeler

* **Zaman Bazlı Dinamik Karşılama Mesajları (Dashboard Screen):**
  * [dashboard_screen.dart](file:///Users/ecekocak/Desktop/expenza-main/mobile/lib/screens/dashboard_screen.dart#L89) dosyasındaki `_greeting` özelliği güncellendi. Kullanıcının yerel saatine göre dinamik olarak şu mesajlar gösterilmektedir:
    * **05:00 - 12:00:** "Günaydın"
    * **12:00 - 18:00:** "İyi günler"
    * **18:00 - 22:00:** "İyi akşamlar"
    * **22:00 - 05:00:** "İyi geceler"

* **İşlem Satırlarında Gereksiz Zaman Gösteriminin Kaldırılması (History Screen):**
  * SQLite veritabanı harcama zamanını tarih seviyesinde sakladığından, elle girilen harcamalarda saat `00:00` olarak görüntüleniyordu.
  * [history_screen.dart](file:///Users/ecekocak/Desktop/expenza-main/mobile/lib/screens/history_screen.dart#L387) dosyasında, eğer işlemin saat ve dakikası sıfır ise (`00:00`) saat bilgisinin arayüzde gösterilmemesi sağlandı.

* **Ana Sayfa Scroll Sınırı Düzeltmesi (Dashboard Screen):**
  * Floating (yüzen) alt navigasyon barı nedeniyle Dashboard ekranının en altındaki elemanların bir kısmı kapatılıyordu ve tamamen yukarı kaydırılamıyordu.
  * [dashboard_screen.dart](file:///Users/ecekocak/Desktop/expenza-main/mobile/lib/screens/dashboard_screen.dart#L120) dosyasındaki `ListView` alt dolgu mesafesi (padding) `32` değerinden `120` değerine yükseltilerek tüm elemanların tam olarak kaydırılabilmesi sağlandı.

* **Gemini Tabanlı Yapay Zekâ Kategori Önerisi (ML Categorizer):**
  * [categorizer.py](file:///Users/ecekocak/Desktop/expenza-main/backend/app/ml/categorizer.py#L117) dosyasına `GeminiCategorizer` sınıfı eklenerek, not alanına açıklama yazıldığında Gemini API üzerinden gerçek zamanlı, yüksek doğruluklu harcama kategorisi sınıflandırması yapılması sağlandı.
  * Gemini API Anahtarı bulunmadığında veya ağ hatası oluştuğunda sistem otomatik olarak yerel TF-IDF+SVM modeline veya kural tabanlı stub'a geri düşmektedir (fallback).

* **Her Ay Otomatik Tekrarlanan Gelir Kaydı (Recurring Income):**
  * **Veritabanı Seviyesi:** SQLite `transactions` tablosuna [models.py](file:///Users/ecekocak/Desktop/expenza-main/backend/app/models.py#L73) üzerinde `is_recurring` (BOOLEAN) alanı eklendi ve mevcut veritabanı güncellendi.
  * **İnteraktif Arayüz:** Gelir ekleme ekranında (`AddTransactionScreen`), sadece tür "Gelir" olduğunda görünen **"Gelir kaydedilsin mi"** onay kutusu (checkbox) eklendi.
  * **Alert İletişim Kutusu:** Kullanıcı onay kutusuna tıkladığında ekranda *"Kabul ederseniz her ay otomatik olarak gelir olarak hesaplanacaktır. Devam etmek istiyor musunuz? Evet / Hayır"* seçenekli şık bir onay kutusu belirir.
  * **Lazy Generation (Arka Plan Otomatik Üretim):** [transactions.py](file:///Users/ecekocak/Desktop/expenza-main/backend/app/routers/transactions.py#L15) backend router'ı içerisine lazy-generation mekanizması entegre edildi. Kullanıcı uygulamayı her açtığında veya işlemler listesini yüklediğinde, tekrarlanan işlem tarihi gelmiş olan sonraki aylar için sistem otomatik olarak yeni gelir kayıtları üretir (Yıl geçişleri ve ay uzunlukları gözetilir).

### 2. Önceki Geliştirmeler

* **Gece Modu (Karanlık Tema) Hatası Düzeltildi:**
  * [main.dart](file:///Users/ecekocak/Desktop/expenza-main/mobile/lib/main.dart) dosyasında tema değişimlerinde tüm widget ağacının tetiklenmesi sağlandı.
* **Para Birimi Seçimi (Profile -> Para Birimi):**
  * Profil ekranından Türk Lirası (₺), Dolar ($), Euro (€) ve Sterlin (£) seçimi yapılması ve tüm sistemde dinamik olarak güncellenmesi sağlandı.

## Yapılan Testler ve Doğrulama

1. **Zaman Grubu Karşılama Testi:**
   - Bilgisayarın yerel saati değiştirilerek (06:00, 14:00, 19:00, 23:00) ana sayfadaki "Günaydın", "İyi günler", "İyi akşamlar", "İyi geceler" mesajlarının saat aralıklarına göre doğru şekilde değiştiği doğrulandı.
2. **Saat 00:00 Gizleme Testi:**
   - İşlemler listesinde eski harcamaların altında saat olarak `00:00` yazan ibarelerin gizlendiği, sadece ilgili kategori isminin temiz bir şekilde yer aldığı teyit edildi.
3. **Kaydırma (Scroll) Testi:**
   - Dashboard ekranının en altındaki "Son İşlemler" listesinin tamamen yukarı kaydırılabildiği ve alt barın altında kalmadığı doğrulandı.
4. **Onay Kutusu ve Alert Diyaloğu:**
   - Gelir ekleme sayfasında checkbox'a tıklandığında uyarı penceresinin açıldığı, "Evet" tıklandığında seçili kaldığı, "Hayır" tıklandığında seçimin kalktığı doğrulandı.
   - 10 Mayıs tarihiyle oluşturulan tekrarlı gelirin, bugün (3 Temmuz) listelendiğinde 10 Haziran tarihli tekrarının otomatik olarak arka planda oluşturulduğu ve listeye yansıdığı gözlemlendi.
