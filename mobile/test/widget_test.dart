// Giriş ekranı widget testleri.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expenza_mobile/main.dart';

void main() {
  testWidgets('Açılışta giriş ekranı görünür', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenzaApp());
    await tester.pumpAndSettle();

    expect(find.text('Expenza'), findsOneWidget);
    // "Giriş Yap" hem üstteki sekmede hem gönder butonunda yazar.
    expect(find.text('Giriş Yap'), findsNWidgets(2));
    expect(find.byType(TextField), findsNWidgets(2)); // e-posta ve parola
    expect(find.text('AD SOYAD'), findsNothing);
  });

  testWidgets('Kayıt sekmesi ad alanını açar', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenzaApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kayıt Ol').first);
    await tester.pumpAndSettle();

    expect(find.text('AD SOYAD'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Şifremi unuttum'), findsNothing);
  });
}
