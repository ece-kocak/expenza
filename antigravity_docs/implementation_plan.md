# AI Chatbot (Gemini API Entegrasyonu) Uygulama Planı

Bu plan, Expenza uygulamasına yapay zekâ destekli bir finansal asistan eklemek için gereken backend ve mobil değişikliklerini detaylandırmaktadır.

## Kullanıcı İncelemesi Gerekenler

> [!IMPORTANT]
> **Gemini API Anahtarı:** 
> Chatbot'un çalışması için bir Gemini API anahtarına ihtiyacımız olacak. API anahtarını yerel ortamda backend klasöründeki `.env` dosyasına `GEMINI_API_KEY=your_key_here` şeklinde ekleyeceğiz.

## Önerilen Değişiklikler

---

### 1. Backend (Python/FastAPI) Katmanı

Backend tarafında, gelen soruları kullanıcının verileriyle harmanlayarak (RAG - Retrieval-Augmented Generation yöntemiyle) Gemini API'ye gönderecek bir endpoint oluşturacağız.

#### [NEW] [chat.py](file:///Users/ecekocak/Desktop/expenza-main/backend/app/routers/chat.py)
* Yeni bir `/chat` router'ı oluşturulacak.
* POST `/chat` isteği bir `message: str` alacak.
* İstek yapıldığında, veritabanından kullanıcının:
  * Son 30 gündeki harcamaları/gelirleri (kategori ve tutarlarıyla),
  * Bütçe limitleri,
  * Tasarruf hedefleri çekilerek Gemini'a gönderilecek sistemsel mesaja (context) eklenecek.
* Gemini'dan gelen yanıt metni markdown formatında mobil uygulamaya dönecek.

#### [MODIFY] [main.py](file:///Users/ecekocak/Desktop/expenza-main/backend/app/main.py)
* Yeni oluşturulan `chat_router` uygulamaya dahil edilecek.

#### [MODIFY] [requirements.txt](file:///Users/ecekocak/Desktop/expenza-main/backend/requirements.txt)
* Gemini API ile kolay iletişim kurabilmek için `google-generativeai` veya API istekleri için `httpx` kütüphanesi eklenecek.

---

### 2. Mobil (Flutter) Katmanı

#### [NEW] [chat_screen.dart](file:///Users/ecekocak/Desktop/expenza-main/mobile/lib/screens/chat_screen.dart)
* Kullanıcı ve AI mesaj balonlarını içeren, Expenza'nın monokrom "Quiet Premium" tasarım diline uygun sohbet arayüzü.
* Mesaj yazma kutusu ve gönderme butonu.
* Yapay zekanın o an düşündüğünü gösteren şık bir "Yazıyor..." animasyonu (Typening indicator).

#### [MODIFY] [api_client.dart](file:///Users/ecekocak/Desktop/expenza-main/mobile/lib/api_client.dart)
* Backend'deki `/chat` endpoint'ine bağlanacak `Future<String> sendChatMessage(String message)` metodu eklenecek.

#### [MODIFY] [dashboard_screen.dart](file:///Users/ecekocak/Desktop/expenza-main/mobile/lib/screens/dashboard_screen.dart)
* Ana sayfadaki (Dashboard) sağ üst kısımdaki tema butonunun hemen soluna bir **sohbet balonu ikonu** (AI Asistan) yerleştirilecek. Tıklandığında `ChatScreen` sayfasına yönlendirecek.

---

## Doğrulama Planı

### Otomatik & Manuel Testler
- Backend'de `/chat` endpoint'ine istek gönderip gelen yanıtı test etmek.
- Mobil arayüzde asistanla sohbet edip, *"Bu ayki bütçem ne durumda?"*, *"Bana tasarruf önerisi ver"* gibi sorular sorarak veritabanındaki bilgilerimizle doğru yanıt verip vermediğini manuel doğrulamak.
