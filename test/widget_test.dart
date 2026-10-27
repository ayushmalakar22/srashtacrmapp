// Basic smoke test: the app should build without throwing while it
// checks the stored login session.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:srashtacrmapp/providers/auth_provider.dart';
import 'package:srashtacrmapp/main.dart';

void main() {
  testWidgets('App builds with no crash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const SrashtaCrmApp(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
