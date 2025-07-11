import 'package:flutter_test/flutter_test.dart';
import 'package:arcane_forge/main.dart';

void main() {
  testWidgets('shows login screen when not authenticated', (tester) async {
    await tester.pumpWidget(MyApp());
    expect(find.text('Sign In'), findsOneWidget);
  });
}
