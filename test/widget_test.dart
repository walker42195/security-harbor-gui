import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/main.dart';

void main() {
  testWidgets('Security Harbor App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(const SecurityHarborApp());
    expect(find.byType(SecurityHarborApp), findsOneWidget);
  });
}
