// Temel akıllılık testi: uygulama açılışta giriş ekranını gösterir.
import 'package:flutter_test/flutter_test.dart';

import 'package:expenza_mobile/main.dart';

void main() {
  testWidgets('Açılışta giriş ekranı görünür', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenzaApp());
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
