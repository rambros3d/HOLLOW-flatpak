import 'package:flutter_test/flutter_test.dart';

import 'package:hollow/src/ui/app.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const HollowApp());
  });
}
