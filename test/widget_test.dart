import 'package:flutter_test/flutter_test.dart';

import 'package:rain_person_2/main.dart';

void main() {
  testWidgets('App starts with PageOne title', (WidgetTester tester) async {
    await tester.pumpWidget(const RainPersonApp());

    expect(find.text('雨中人2'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
  });
}
