import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Fiş tarama sonucu.
class ReceiptScan {
  final double? amount;
  final String merchant;
  final String rawText;
  ReceiptScan({this.amount, required this.merchant, required this.rawText});
}

/// Cihaz-üstü fiş OCR'ı (Google ML Kit). Web'de desteklenmez (mobil eklenti).
class OcrService {
  /// ML Kit yalnızca iOS/Android'de çalışır.
  static bool get supported => !kIsWeb;

  static final _picker = ImagePicker();

  /// Kamera veya galeriden görsel al → metin oku → tutar/işyeri ayrıştır.
  /// Görsel seçilmezse null döner.
  static Future<ReceiptScan?> scan(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(file.path));
      return _parse(result.text);
    } finally {
      await recognizer.close();
    }
  }

  // ---- Ayrıştırma (sezgisel; demo için yeterli) ----

  static ReceiptScan _parse(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final amount = _findTotal(lines) ?? _maxMoney(text);
    final merchant = _findMerchant(lines);
    return ReceiptScan(amount: amount, merchant: merchant, rawText: text);
  }

  // Türkçe para: 1.234,56 (nokta binlik, virgül ondalık)
  static final _moneyRe =
      RegExp(r'(\d{1,3}(?:\.\d{3})*|\d+),(\d{2})');

  static double? _toDouble(String s) {
    final clean = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean);
  }

  /// "TOPLAM" / "TUTAR" / "GENEL TOPLAM" geçen satırdaki tutarı bul (en güvenilir).
  static double? _findTotal(List<String> lines) {
    final keys = ['GENEL TOPLAM', 'TOPLAM', 'TUTAR', 'ODENEN', 'ÖDENEN'];
    double? best;
    for (final line in lines) {
      final up = line.toUpperCase();
      if (keys.any(up.contains)) {
        // KDV toplamını yanlışlıkla almamak için "KDV" içeren satırları atla
        if (up.contains('KDV') && !up.contains('TOPLAM')) continue;
        final matches = _moneyRe.allMatches(line);
        if (matches.isNotEmpty) {
          final v = _toDouble(matches.last.group(0)!);
          if (v != null && (best == null || v > best)) best = v;
        }
      }
    }
    return best;
  }

  /// Anahtar kelime yoksa: metindeki en büyük para değeri (genelde toplam).
  static double? _maxMoney(String text) {
    double? maxV;
    for (final m in _moneyRe.allMatches(text)) {
      final v = _toDouble(m.group(0)!);
      if (v != null && (maxV == null || v > maxV)) maxV = v;
    }
    return maxV;
  }

  /// İşyeri adı: baştaki, harf içeren, sayı/tarih olmayan ilk anlamlı satır.
  static String _findMerchant(List<String> lines) {
    final skip = RegExp(r'(FI[ŞS]|FATURA|TAR[İI]H|SAAT|NO:|VKN|TCKN|MERSIS)',
        caseSensitive: false);
    for (final line in lines.take(6)) {
      final letters = line.replaceAll(RegExp(r'[^A-Za-zĞÜŞİÖÇğüşıöç]'), '');
      if (letters.length >= 3 && !skip.hasMatch(line) && !_moneyRe.hasMatch(line)) {
        return line.length > 40 ? line.substring(0, 40) : line;
      }
    }
    return lines.isNotEmpty ? lines.first : '';
  }
}
