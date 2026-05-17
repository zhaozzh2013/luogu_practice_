import 'package:flutter_test/flutter_test.dart';
import 'package:luogu_practice/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LuoguPracticeApp());
    expect(find.text('洛谷刷题'), findsOneWidget);
  });
}
