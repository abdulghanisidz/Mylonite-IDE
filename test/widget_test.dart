import 'package:flutter_test/flutter_test.dart';

import 'package:mylonite/main.dart';

/// Smoke test — Mylonite IDE home screen renders without crashing.
void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyloniteApp());
    await tester.pumpAndSettle();
    expect(find.text('Mylonite IDE'), findsWidgets);
  });
}
