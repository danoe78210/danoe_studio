import 'package:flutter_test/flutter_test.dart';
import 'package:danoestudio/main.dart';

void main() {
  testWidgets('L\'application démarre', (WidgetTester tester) async {
    await tester.pumpWidget(const DanoestudioApp());
    expect(find.text('Danoë Studio'), findsOneWidget);
  });
}