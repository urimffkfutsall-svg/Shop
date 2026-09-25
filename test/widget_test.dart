import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ecommerce_app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Ballina e re hapet dhe ndërrimi i gjuhës funksionon',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const StoreApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Dyqani Online'), findsOneWidget);
      expect(find.text('Kryefaqja'), findsOneWidget);
      expect(find.text('Shporta'), findsOneWidget);

      await tester.tap(find.text('EN').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Cart'), findsOneWidget);
    },
  );
}
