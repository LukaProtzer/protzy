import 'package:flutter_test/flutter_test.dart';
import 'package:protzy/app.dart';

void main() {
  testWidgets('Protzy startet', (WidgetTester tester) async {
    await tester.pumpWidget(const ProtzyApp());

    expect(find.text('Home'), findsWidgets);
  });
}