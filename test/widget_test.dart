import 'package:flutter_test/flutter_test.dart';

import 'package:blood_now/main.dart';

void main() {
  testWidgets('Get Started screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BloodNowApp());

    expect(find.text('Blood Now'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
