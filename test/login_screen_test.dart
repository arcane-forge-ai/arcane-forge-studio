import 'package:flutter_test/flutter_test.dart';
import 'package:arcane_forge/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance.client;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-anon-key',
      );
    }
  });

  testWidgets('shows login screen when not authenticated', (tester) async {
    await tester.pumpWidget(MyApp());
    expect(find.text('Sign In'), findsOneWidget);
  });
}
