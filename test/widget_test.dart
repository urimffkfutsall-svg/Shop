import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ecommerce_app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Shqipja është gjuha fillestare dhe kalimi në anglisht funksionon',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const StoreApp());

      // Lejon inicializimin e state-it pa pritur animacionet e pafundme.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Produktet\ntona'), findsOneWidget);
      expect(find.text('Kërko produkte'), findsWidgets);

      await tester.tap(find.text('EN').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Our\nProducts'), findsOneWidget);
      expect(find.text('Search products'), findsWidgets);
    },
  );
}
