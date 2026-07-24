import 'package:flutter_test/flutter_test.dart';
import 'package:translation_platform/main.dart';

void main() {
  testWidgets('shows the translation platform home screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Translation Platform'), findsWidgets);
    expect(find.text('Start Translating'), findsOneWidget);
  });
}
