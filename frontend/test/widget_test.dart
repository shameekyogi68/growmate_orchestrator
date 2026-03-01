import 'package:flutter_test/flutter_test.dart';
import 'package:growmate_frontend/main.dart';

void main() {
  testWidgets('App builds without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const GrowMateApp(hasToken: false));
  });
}
