import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ecommerce_app/app.dart';

void main() {
  testWidgets('Albanian is default and English switch works', (tester) async {
    await tester.pumpWidget(const StoreApp());
    await tester.pumpAndSettle();
    expect(find.text('Produktet\ntona'), findsOneWidget);
    expect(find.text('Kërko produkte'), findsWidgets);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Our\nProducts'), findsOneWidget);
    expect(find.text('Search products'), findsWidgets);
  });
}
